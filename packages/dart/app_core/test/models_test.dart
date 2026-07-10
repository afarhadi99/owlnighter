import 'package:app_core/app_core.dart';
import 'package:test/test.dart';

/// Round-trip and wire-mapping tests for every model. The contract-critical
/// invariant: JSON (de)serialization is lossless and enum wire strings match
/// the backend vocabulary exactly, so an accidental rename can't silently
/// desync the app from the API.
void main() {
  group('enum wire mapping', () {
    test('every enum round-trips value <-> wire', () {
      for (final e in AiProvider.values) {
        expect(AiProvider.fromWire(e.wire), e);
      }
      for (final e in PacingMode.values) {
        expect(PacingMode.fromWire(e.wire), e);
      }
      for (final e in QuizMode.values) {
        expect(QuizMode.fromWire(e.wire), e);
      }
      for (final e in GroundingStatus.values) {
        expect(GroundingStatus.fromWire(e.wire), e);
      }
      for (final e in UserBookStatus.values) {
        expect(UserBookStatus.fromWire(e.wire), e);
      }
      for (final e in StepStatus.values) {
        expect(StepStatus.fromWire(e.wire), e);
      }
      for (final e in QuizQuestionKind.values) {
        expect(QuizQuestionKind.fromWire(e.wire), e);
      }
    });

    test('wire strings match the contract vocabulary', () {
      expect(QuizMode.userText.wire, 'user_text');
      expect(QuizQuestionKind.multipleChoice.wire, 'multiple_choice');
      expect(QuizQuestionKind.trueFalse.wire, 'true_false');
      expect(QuizQuestionKind.shortAnswer.wire, 'short_answer');
      expect(GroundingStatus.blocked.wire, 'blocked');
      expect(UserBookStatus.archived.wire, 'archived');
      expect(StepStatus.available.wire, 'available');
    });

    test('fromWire throws on an unknown value', () {
      expect(() => QuizMode.fromWire('nope'), throwsStateError);
    });
  });

  group('Book', () {
    test('full round-trip preserves every field', () {
      final json = {
        'canonicalTitle': 'Moby-Dick',
        'authors': ['Herman Melville'],
        'confidence': 0.95,
        'editionLabel': 'Penguin Classics',
        'isbn13': '9780142437247',
        'googleBooksId': 'gb1',
        'openLibraryKey': '/works/OL1W',
        'pageCount': 720,
        'languageCode': 'en',
        'publishedYear': 1851,
        'coverUrl': 'https://example.com/cover.jpg',
      };
      final book = Book.fromJson(json);
      expect(book.canonicalTitle, 'Moby-Dick');
      expect(book.authors, ['Herman Melville']);
      expect(book.confidence, 0.95);
      expect(book.authorLine, 'Herman Melville');
      expect(book.toJson(), json);
    });

    test('omits null optionals and parses an int confidence as double', () {
      final book = Book.fromJson({
        'canonicalTitle': 'X',
        'authors': <String>[],
        'confidence': 1, // int on the wire
      });
      expect(book.confidence, 1.0);
      expect(book.toJson().containsKey('isbn13'), isFalse);
    });
  });

  group('CatalogCandidate', () {
    test('round-trip preserves fields and defaults authors to empty', () {
      final c = CatalogCandidate.fromJson({
        'source': 'google_books',
        'sourceId': 'abc',
        'title': 'Dune',
      });
      expect(c.authors, isEmpty);
      final again = CatalogCandidate.fromJson(c.toJson());
      expect(again.source, 'google_books');
      expect(again.title, 'Dune');
    });
  });

  group('Citation', () {
    test('round-trip', () {
      const json = {'title': 't', 'url': 'u', 'reason': 'r'};
      expect(Citation.fromJson(json).toJson(), json);
    });
  });

  group('GroundedBook', () {
    test('parses nested identity, status, and citations', () {
      final g = GroundedBook.fromJson({
        'bookId': 'b1',
        'identity': {
          'canonicalTitle': 'T',
          'authors': ['A'],
          'confidence': 0.8,
        },
        'groundingStatus': 'partial',
        'pageLevelUnsafe': true,
        'citations': [
          {'title': 't', 'url': 'u', 'reason': 'r'},
        ],
      });
      expect(g.bookId, 'b1');
      expect(g.identity.canonicalTitle, 'T');
      expect(g.groundingStatus, GroundingStatus.partial);
      expect(g.pageLevelUnsafe, isTrue);
      expect(g.citations, hasLength(1));
    });
  });

  group('UserBook', () {
    test('enriched round-trip preserves catalog identity', () {
      final json = {
        'id': 'ub1',
        'bookId': '3ce25e75-0000-0000-0000-000000000000',
        'status': 'active',
        'currentPage': 12,
        'targetNightlyPages': 10,
        'title': 'The Hobbit',
        'authors': ['J.R.R. Tolkien'],
        'coverUrl': 'https://example.com/h.jpg',
        'groundingStatus': 'grounded',
        'pageCount': 310,
      };
      final ub = UserBook.fromJson(json);
      expect(ub.title, 'The Hobbit');
      expect(ub.authorLine, 'J.R.R. Tolkien');
      expect(ub.groundingStatus, GroundingStatus.grounded);
      expect(ub.displayTitle, 'The Hobbit');
      expect(ub.toJson(), json);
    });

    test('displayTitle falls back to a short id when un-enriched', () {
      final ub = UserBook.fromJson({
        'id': 'ub1',
        'bookId': '3ce25e75abcd',
        'status': 'active',
      });
      expect(ub.title, isNull);
      expect(ub.authorLine, isNull);
      expect(ub.groundingStatus, isNull);
      expect(ub.displayTitle, 'Book 3ce25e75');
      // Un-enriched toJson omits the optional identity keys.
      expect(ub.toJson().keys, containsAll(['id', 'bookId', 'status']));
      expect(ub.toJson().containsKey('title'), isFalse);
    });

    test('displayTitle tolerates an id shorter than 8 chars', () {
      final ub = UserBook.fromJson({
        'id': 'x',
        'bookId': 'abc',
        'status': 'paused',
      });
      expect(ub.displayTitle, 'Book abc');
    });
  });

  group('PlanStep', () {
    test('round-trip with page range', () {
      final json = {
        'stepIndex': 0,
        'title': 'Night 1',
        'quizMode': 'grounded',
        'prompt': 'Read chapter 1',
        'confidence': 0.9,
        'pageStart': 1,
        'pageEnd': 20,
        'chapterHint': 'Ch. 1',
      };
      final step = PlanStep.fromJson(json);
      expect(step.pageRangeLabel, 'pp. 1–20');
      expect(step.toJson(), json);
    });

    test('pageRangeLabel is null when pages are absent', () {
      final step = PlanStep.fromJson({
        'stepIndex': 1,
        'title': 'Night 2',
        'quizMode': 'preview',
        'prompt': 'p',
        'confidence': 0.5,
      });
      expect(step.pageRangeLabel, isNull);
    });
  });

  group('PlanStepState', () {
    test('round-trip preserves unlocksAt as ISO-8601', () {
      final json = {
        'stepId': 's1',
        'stepIndex': 0,
        'status': 'available',
        'unlocksAt': '2026-07-10T21:00:00.000Z',
        'ttsAssetId': 'tts1',
      };
      final st = PlanStepState.fromJson(json);
      expect(st.status, StepStatus.available);
      expect(st.unlocksAt, isNotNull);
      expect(st.toJson(), json);
    });
  });

  group('ReadingPlan', () {
    ReadingPlan buildPlan() => ReadingPlan.fromJson({
          'planId': 'p1',
          'bookId': 'b1',
          'provider': 'gemini',
          'providerModel': 'gemini-3.5-flash',
          'planVersion': 1,
          'pacingMode': 'standard',
          'nightlyGoalPages': 10,
          'startsOn': '2026-07-10T00:00:00.000Z',
          'steps': [
            {
              'stepIndex': 0,
              'title': 'N1',
              'quizMode': 'grounded',
              'prompt': 'p',
              'confidence': 0.9,
            },
            {
              'stepIndex': 1,
              'title': 'N2',
              'quizMode': 'grounded',
              'prompt': 'p',
              'confidence': 0.9,
            },
          ],
          'stepStates': [
            {'stepId': 's0', 'stepIndex': 0, 'status': 'completed'},
            {'stepId': 's1', 'stepIndex': 1, 'status': 'available'},
          ],
        });

    test('parses steps + states and resolves nextAvailable', () {
      final plan = buildPlan();
      expect(plan.steps, hasLength(2));
      expect(plan.provider, AiProvider.gemini);
      expect(plan.stateForIndex(1)?.stepId, 's1');
      expect(plan.nextAvailable?.stepId, 's1');
    });

    test('nextAvailable is null when nothing is available', () {
      final plan = ReadingPlan.fromJson({
        'planId': 'p1',
        'bookId': 'b1',
        'provider': 'groq',
        'providerModel': 'm',
        'planVersion': 1,
        'pacingMode': 'gentle',
        'nightlyGoalPages': 5,
        'startsOn': '2026-07-10T00:00:00.000Z',
        'steps': const [],
        'stepStates': [
          {'stepId': 's0', 'stepIndex': 0, 'status': 'completed'},
        ],
      });
      expect(plan.nextAvailable, isNull);
    });
  });

  group('GroundedBookPlan', () {
    test('parses the pre-persistence plan shape', () {
      final gp = GroundedBookPlan.fromJson({
        'book': {
          'canonicalTitle': 'T',
          'authors': ['A'],
          'confidence': 0.9,
        },
        'pacingMode': 'intensive',
        'nightlyGoalPages': 20,
        'rationale': 'because',
        'steps': [
          {
            'stepIndex': 0,
            'title': 'N1',
            'quizMode': 'grounded',
            'prompt': 'p',
            'confidence': 0.9,
          },
        ],
      });
      expect(gp.pacingMode, PacingMode.intensive);
      expect(gp.steps, hasLength(1));
      expect(gp.citations, isEmpty);
    });
  });

  group('Quiz models', () {
    test('QuizQuestion round-trip', () {
      final json = {
        'id': 'q1',
        'kind': 'multiple_choice',
        'prompt': 'Who?',
        'quizMode': 'grounded',
        'options': ['a', 'b'],
        'sourceCitationIndex': 2,
      };
      final q = QuizQuestion.fromJson(json);
      expect(q.kind, QuizQuestionKind.multipleChoice);
      expect(q.toJson(), json);
    });

    test('QuizInstance round-trip', () {
      final json = {
        'quizId': 'qi1',
        'stepId': 's1',
        'quizMode': 'grounded',
        'questions': [
          {
            'id': 'q1',
            'kind': 'true_false',
            'prompt': 'p',
            'quizMode': 'grounded',
          },
        ],
        'generatedByProvider': 'groq',
        'generatedByModel': 'qwen',
        'confidence': 0.7,
      };
      final qi = QuizInstance.fromJson(json);
      expect(qi.questions, hasLength(1));
      expect(qi.generatedByProvider, AiProvider.groq);
      expect(qi.toJson(), json);
    });

    test('QuizAnswer serializes to the submit shape', () {
      const a = QuizAnswer(questionId: 'q1', answer: 'True');
      expect(a.toJson(), {'questionId': 'q1', 'answer': 'True'});
    });

    test('QuizResult parses per-question grading and streak delta', () {
      final r = QuizResult.fromJson({
        'quizId': 'qi1',
        'correctCount': 3,
        'totalCount': 4,
        'passed': true,
        'markedComplete': true,
        'perQuestion': [
          {
            'questionId': 'q1',
            'correct': true,
            'correctAnswer': 'A',
            'explanation': 'because',
          },
          {
            'questionId': 'q2',
            'correct': false,
            'correctAnswer': 'B',
          },
        ],
        'streak': {
          'currentStreak': 2,
          'longestStreak': 5,
          'xpGained': 20,
        },
      });
      expect(r.correctCount, 3);
      expect(r.passed, isTrue);
      expect(r.perQuestion, hasLength(2));
      expect(r.perQuestion.first.explanation, 'because');
      expect(r.perQuestion[1].explanation, isNull);
      expect(r.streak.currentStreak, 2);
      expect(r.streak.xpGained, 20);
      expect(r.streak.isActive, isTrue);
    });

    test('StreakState defaults xpGained to 0 and isActive false at zero', () {
      final s = StreakState.fromSubmitJson({
        'currentStreak': 0,
        'longestStreak': 0,
      });
      expect(s.xpGained, 0);
      expect(s.isActive, isFalse);
    });
  });
}
