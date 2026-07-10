import 'package:meta/meta.dart';

import 'enums.dart';

/// Canonical, edition-level identity of a book. Mirrors `BookIdentity` in
/// contracts/book.ts. Immutable value type.
@immutable
class Book {
  const Book({
    required this.canonicalTitle,
    required this.authors,
    required this.confidence,
    this.editionLabel,
    this.isbn13,
    this.googleBooksId,
    this.openLibraryKey,
    this.pageCount,
    this.languageCode,
    this.publishedYear,
    this.coverUrl,
  });

  final String canonicalTitle;
  final List<String> authors;
  final double confidence;
  final String? editionLabel;
  final String? isbn13;
  final String? googleBooksId;
  final String? openLibraryKey;
  final int? pageCount;
  final String? languageCode;
  final int? publishedYear;
  final String? coverUrl;

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        canonicalTitle: json['canonicalTitle'] as String,
        authors:
            (json['authors'] as List<dynamic>).map((e) => e as String).toList(),
        confidence: (json['confidence'] as num).toDouble(),
        editionLabel: json['editionLabel'] as String?,
        isbn13: json['isbn13'] as String?,
        googleBooksId: json['googleBooksId'] as String?,
        openLibraryKey: json['openLibraryKey'] as String?,
        pageCount: json['pageCount'] as int?,
        languageCode: json['languageCode'] as String?,
        publishedYear: json['publishedYear'] as int?,
        coverUrl: json['coverUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'canonicalTitle': canonicalTitle,
        'authors': authors,
        'confidence': confidence,
        if (editionLabel != null) 'editionLabel': editionLabel,
        if (isbn13 != null) 'isbn13': isbn13,
        if (googleBooksId != null) 'googleBooksId': googleBooksId,
        if (openLibraryKey != null) 'openLibraryKey': openLibraryKey,
        if (pageCount != null) 'pageCount': pageCount,
        if (languageCode != null) 'languageCode': languageCode,
        if (publishedYear != null) 'publishedYear': publishedYear,
        if (coverUrl != null) 'coverUrl': coverUrl,
      };

  String get authorLine => authors.join(', ');
}

/// A raw candidate returned by a deterministic catalog source. Mirrors
/// `CatalogCandidate`.
@immutable
class CatalogCandidate {
  const CatalogCandidate({
    required this.source,
    required this.sourceId,
    required this.title,
    this.authors = const [],
    this.isbn13,
    this.pageCount,
    this.publishedYear,
    this.languageCode,
    this.coverUrl,
    this.rawUrl,
  });

  final String source; // "google_books" | "open_library"
  final String sourceId;
  final String title;
  final List<String> authors;
  final String? isbn13;
  final int? pageCount;
  final int? publishedYear;
  final String? languageCode;
  final String? coverUrl;
  final String? rawUrl;

  factory CatalogCandidate.fromJson(Map<String, dynamic> json) =>
      CatalogCandidate(
        source: json['source'] as String,
        sourceId: json['sourceId'] as String,
        title: json['title'] as String,
        authors: (json['authors'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        isbn13: json['isbn13'] as String?,
        pageCount: json['pageCount'] as int?,
        publishedYear: json['publishedYear'] as int?,
        languageCode: json['languageCode'] as String?,
        coverUrl: json['coverUrl'] as String?,
        rawUrl: json['rawUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'sourceId': sourceId,
        'title': title,
        'authors': authors,
        if (isbn13 != null) 'isbn13': isbn13,
        if (pageCount != null) 'pageCount': pageCount,
        if (publishedYear != null) 'publishedYear': publishedYear,
        if (languageCode != null) 'languageCode': languageCode,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (rawUrl != null) 'rawUrl': rawUrl,
      };
}

/// A citation backing a grounded fact. Shared shape across book/plan/quiz.
@immutable
class Citation {
  const Citation({
    required this.title,
    required this.url,
    required this.reason,
  });

  final String title;
  final String url;
  final String reason;

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        title: json['title'] as String,
        url: json['url'] as String,
        reason: json['reason'] as String,
      );

  Map<String, dynamic> toJson() =>
      {'title': title, 'url': url, 'reason': reason};
}

/// Result of grounding a book. Mirrors `BookGroundResponse`.
@immutable
class GroundedBook {
  const GroundedBook({
    required this.bookId,
    required this.identity,
    required this.groundingStatus,
    required this.pageLevelUnsafe,
    this.citations = const [],
  });

  final String bookId;
  final Book identity;
  final GroundingStatus groundingStatus;
  final bool pageLevelUnsafe;
  final List<Citation> citations;

  factory GroundedBook.fromJson(Map<String, dynamic> json) => GroundedBook(
        bookId: json['bookId'] as String,
        identity: Book.fromJson(json['identity'] as Map<String, dynamic>),
        groundingStatus:
            GroundingStatus.fromWire(json['groundingStatus'] as String),
        pageLevelUnsafe: json['pageLevelUnsafe'] as bool,
        citations: (json['citations'] as List<dynamic>? ?? const [])
            .map((e) => Citation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A book in the user's library. Mirrors `LibraryBook`.
///
/// The list endpoint enriches each item with catalog identity ([title],
/// [authors], [coverUrl], [groundingStatus], [pageCount]) so the library can
/// render a real book instead of a raw id. These are optional on the wire: an
/// older API (or a not-yet-enriched row) simply omits them and the UI falls
/// back to [displayTitle].
@immutable
class UserBook {
  const UserBook({
    required this.id,
    required this.bookId,
    required this.status,
    this.currentPage,
    this.targetNightlyPages,
    this.title,
    this.authors = const [],
    this.coverUrl,
    this.groundingStatus,
    this.pageCount,
  });

  final String id;
  final String bookId;
  final UserBookStatus status;
  final int? currentPage;
  final int? targetNightlyPages;
  final String? title;
  final List<String> authors;
  final String? coverUrl;
  final GroundingStatus? groundingStatus;
  final int? pageCount;

  factory UserBook.fromJson(Map<String, dynamic> json) => UserBook(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        status: UserBookStatus.fromWire(json['status'] as String),
        currentPage: json['currentPage'] as int?,
        targetNightlyPages: json['targetNightlyPages'] as int?,
        title: json['title'] as String?,
        authors: (json['authors'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        coverUrl: json['coverUrl'] as String?,
        groundingStatus: json['groundingStatus'] == null
            ? null
            : GroundingStatus.fromWire(json['groundingStatus'] as String),
        pageCount: json['pageCount'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'status': status.wire,
        if (currentPage != null) 'currentPage': currentPage,
        if (targetNightlyPages != null)
          'targetNightlyPages': targetNightlyPages,
        if (title != null) 'title': title,
        if (authors.isNotEmpty) 'authors': authors,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (groundingStatus != null) 'groundingStatus': groundingStatus!.wire,
        if (pageCount != null) 'pageCount': pageCount,
      };

  /// The book's display title, falling back to a short id when the list item
  /// hasn't been enriched with catalog identity yet.
  String get displayTitle =>
      title ?? 'Book ${bookId.substring(0, bookId.length.clamp(0, 8))}';

  /// Comma-joined authors, or null when unknown.
  String? get authorLine => authors.isEmpty ? null : authors.join(', ');
}
