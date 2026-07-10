import 'package:meta/meta.dart';

import 'book.dart';
import 'enums.dart';

/// One night's worth of reading. Mirrors `PlanStep` in contracts/plan.ts.
@immutable
class PlanStep {
  const PlanStep({
    required this.stepIndex,
    required this.title,
    required this.quizMode,
    required this.prompt,
    required this.confidence,
    this.pageStart,
    this.pageEnd,
    this.chapterHint,
  });

  final int stepIndex;
  final String title;
  final QuizMode quizMode;
  final String prompt;
  final double confidence;
  final int? pageStart;
  final int? pageEnd;
  final String? chapterHint;

  factory PlanStep.fromJson(Map<String, dynamic> json) => PlanStep(
        stepIndex: json['stepIndex'] as int,
        title: json['title'] as String,
        quizMode: QuizMode.fromWire(json['quizMode'] as String),
        prompt: json['prompt'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        pageStart: json['pageStart'] as int?,
        pageEnd: json['pageEnd'] as int?,
        chapterHint: json['chapterHint'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'stepIndex': stepIndex,
        'title': title,
        'quizMode': quizMode.wire,
        'prompt': prompt,
        'confidence': confidence,
        if (pageStart != null) 'pageStart': pageStart,
        if (pageEnd != null) 'pageEnd': pageEnd,
        if (chapterHint != null) 'chapterHint': chapterHint,
      };

  /// Human page range, e.g. "pp. 12–24", or null when the step is chapter-based.
  String? get pageRangeLabel {
    if (pageStart == null || pageEnd == null) return null;
    return 'pp. $pageStart–$pageEnd';
  }
}

/// Reader-facing state attached to a step. Mirrors `PlanStepState`.
@immutable
class PlanStepState {
  const PlanStepState({
    required this.stepId,
    required this.stepIndex,
    required this.status,
    this.unlocksAt,
    this.ttsAssetId,
  });

  final String stepId;
  final int stepIndex;
  final StepStatus status;
  final DateTime? unlocksAt;
  final String? ttsAssetId;

  factory PlanStepState.fromJson(Map<String, dynamic> json) => PlanStepState(
        stepId: json['stepId'] as String,
        stepIndex: json['stepIndex'] as int,
        status: StepStatus.fromWire(json['status'] as String),
        unlocksAt: json['unlocksAt'] == null
            ? null
            : DateTime.parse(json['unlocksAt'] as String),
        ttsAssetId: json['ttsAssetId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'stepId': stepId,
        'stepIndex': stepIndex,
        'status': status.wire,
        if (unlocksAt != null) 'unlocksAt': unlocksAt!.toIso8601String(),
        if (ttsAssetId != null) 'ttsAssetId': ttsAssetId,
      };
}

/// A lightweight plan row for list views. Mirrors `PlanSummary` in
/// contracts/plan.ts — cheaper than [ReadingPlan] (no steps or step states).
/// Returned by `GET /v1/plans?bookId=`; the client fetches the full plan via
/// [PlanRepository.getPlan] on tap.
@immutable
class PlanSummary {
  const PlanSummary({
    required this.planId,
    required this.bookId,
    required this.planVersion,
    required this.pacingMode,
    required this.nightlyGoalPages,
    required this.startsOn,
    required this.createdAt,
  });

  final String planId;
  final String bookId;
  final int planVersion;
  final PacingMode pacingMode;
  final int nightlyGoalPages;
  final DateTime startsOn;
  final DateTime createdAt;

  factory PlanSummary.fromJson(Map<String, dynamic> json) => PlanSummary(
        planId: json['planId'] as String,
        bookId: json['bookId'] as String,
        planVersion: json['planVersion'] as int,
        pacingMode: PacingMode.fromWire(json['pacingMode'] as String),
        nightlyGoalPages: json['nightlyGoalPages'] as int,
        startsOn: DateTime.parse(json['startsOn'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'bookId': bookId,
        'planVersion': planVersion,
        'pacingMode': pacingMode.wire,
        'nightlyGoalPages': nightlyGoalPages,
        'startsOn': startsOn.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A full reading plan with steps and their states. Mirrors `PlanResponse`.
@immutable
class ReadingPlan {
  const ReadingPlan({
    required this.planId,
    required this.bookId,
    required this.provider,
    required this.providerModel,
    required this.planVersion,
    required this.pacingMode,
    required this.nightlyGoalPages,
    required this.startsOn,
    required this.steps,
    required this.stepStates,
    this.endsOn,
  });

  final String planId;
  final String bookId;
  final AiProvider provider;
  final String providerModel;
  final int planVersion;
  final PacingMode pacingMode;
  final int nightlyGoalPages;
  final DateTime startsOn;
  final DateTime? endsOn;
  final List<PlanStep> steps;
  final List<PlanStepState> stepStates;

  factory ReadingPlan.fromJson(Map<String, dynamic> json) => ReadingPlan(
        planId: json['planId'] as String,
        bookId: json['bookId'] as String,
        provider: AiProvider.fromWire(json['provider'] as String),
        providerModel: json['providerModel'] as String,
        planVersion: json['planVersion'] as int,
        pacingMode: PacingMode.fromWire(json['pacingMode'] as String),
        nightlyGoalPages: json['nightlyGoalPages'] as int,
        startsOn: DateTime.parse(json['startsOn'] as String),
        endsOn: json['endsOn'] == null
            ? null
            : DateTime.parse(json['endsOn'] as String),
        steps: (json['steps'] as List<dynamic>)
            .map((e) => PlanStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        stepStates: (json['stepStates'] as List<dynamic>)
            .map((e) => PlanStepState.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Pair a step with its state by index for rendering the path map.
  PlanStepState? stateForIndex(int stepIndex) {
    for (final s in stepStates) {
      if (s.stepIndex == stepIndex) return s;
    }
    return null;
  }

  /// The next actionable step (first `available`), or null if none.
  PlanStepState? get nextAvailable {
    for (final s in stepStates) {
      if (s.status == StepStatus.available) return s;
    }
    return null;
  }
}

/// A generated plan straight from the model, pre-persistence. Mirrors
/// `GroundedBookPlan` — used by admin/debug preview flows.
@immutable
class GroundedBookPlan {
  const GroundedBookPlan({
    required this.book,
    required this.pacingMode,
    required this.nightlyGoalPages,
    required this.rationale,
    required this.steps,
    this.citations = const [],
  });

  final Book book;
  final PacingMode pacingMode;
  final int nightlyGoalPages;
  final String rationale;
  final List<PlanStep> steps;
  final List<Citation> citations;

  factory GroundedBookPlan.fromJson(Map<String, dynamic> json) =>
      GroundedBookPlan(
        book: Book.fromJson(json['book'] as Map<String, dynamic>),
        pacingMode: PacingMode.fromWire(json['pacingMode'] as String),
        nightlyGoalPages: json['nightlyGoalPages'] as int,
        rationale: json['rationale'] as String,
        steps: (json['steps'] as List<dynamic>)
            .map((e) => PlanStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        citations: (json['citations'] as List<dynamic>? ?? const [])
            .map((e) => Citation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
