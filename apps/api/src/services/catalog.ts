import type { CatalogCandidate } from "@owlnighter/contracts";
import type { Env, Logger } from "@owlnighter/shared";

/**
 * Deterministic catalog resolution. We query Google Books and Open Library in
 * parallel, normalise each hit into a `CatalogCandidate`, and merge/dedupe by
 * ISBN-13 (falling back to a title+author key). No AI here — catalog APIs are
 * stable and fast for identity resolution; grounding handles ambiguity later.
 */

interface SearchParams {
  title: string;
  author?: string;
  isbn13?: string;
  limit: number;
}

const GOOGLE_BOOKS_URL = "https://www.googleapis.com/books/v1/volumes";

/** Pull a 13-digit ISBN out of Google's industryIdentifiers array. */
function googleIsbn13(ids: Array<{ type?: string; identifier?: string }> | undefined): string | undefined {
  const hit = ids?.find((i) => i.type === "ISBN_13" && /^\d{13}$/.test(i.identifier ?? ""));
  return hit?.identifier;
}

async function searchGoogleBooks(env: Env, log: Logger, p: SearchParams): Promise<CatalogCandidate[]> {
  // Build a Google Books `q` using field-qualified terms for precision.
  const terms: string[] = [];
  if (p.isbn13) terms.push(`isbn:${p.isbn13}`);
  else {
    terms.push(`intitle:${p.title}`);
    if (p.author) terms.push(`inauthor:${p.author}`);
  }
  const url = new URL(GOOGLE_BOOKS_URL);
  url.searchParams.set("q", terms.join("+"));
  url.searchParams.set("maxResults", String(Math.min(p.limit, 20)));
  url.searchParams.set("printType", "books");
  if (env.GOOGLE_BOOKS_API_KEY) url.searchParams.set("key", env.GOOGLE_BOOKS_API_KEY);

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) {
      log.warn({ status: res.status }, "google books search non-ok");
      return [];
    }
    const body = (await res.json()) as {
      items?: Array<{
        id?: string;
        volumeInfo?: {
          title?: string;
          authors?: string[];
          industryIdentifiers?: Array<{ type?: string; identifier?: string }>;
          pageCount?: number;
          publishedDate?: string;
          language?: string;
          imageLinks?: { thumbnail?: string };
          infoLink?: string;
        };
      }>;
    };
    const items = body.items ?? [];
    return items
      .filter((it) => it.id && it.volumeInfo?.title)
      .map((it): CatalogCandidate => {
        const v = it.volumeInfo!;
        const year = v.publishedDate ? Number.parseInt(v.publishedDate.slice(0, 4), 10) : undefined;
        // Google thumbnails come over http; upgrade to https to keep clients happy.
        const cover = v.imageLinks?.thumbnail?.replace(/^http:/, "https:");
        const c: CatalogCandidate = {
          source: "google_books",
          sourceId: it.id!,
          title: v.title!,
          authors: v.authors ?? [],
        };
        const isbn = googleIsbn13(v.industryIdentifiers);
        if (isbn) c.isbn13 = isbn;
        if (v.pageCount && v.pageCount > 0) c.pageCount = v.pageCount;
        if (year && Number.isFinite(year)) c.publishedYear = year;
        if (v.language) c.languageCode = v.language;
        if (cover) c.coverUrl = cover;
        if (v.infoLink) c.rawUrl = v.infoLink;
        return c;
      });
  } catch (err) {
    log.warn({ err }, "google books search failed");
    return [];
  }
}

async function searchOpenLibrary(env: Env, log: Logger, p: SearchParams): Promise<CatalogCandidate[]> {
  const url = new URL("/search.json", env.OPEN_LIBRARY_BASE_URL);
  if (p.isbn13) url.searchParams.set("isbn", p.isbn13);
  else {
    url.searchParams.set("title", p.title);
    if (p.author) url.searchParams.set("author", p.author);
  }
  url.searchParams.set("limit", String(Math.min(p.limit, 20)));
  // Only request the fields we map — keeps the payload small.
  url.searchParams.set(
    "fields",
    "key,title,author_name,first_publish_year,number_of_pages_median,isbn,language,cover_i",
  );

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) {
      log.warn({ status: res.status }, "open library search non-ok");
      return [];
    }
    const body = (await res.json()) as {
      docs?: Array<{
        key?: string;
        title?: string;
        author_name?: string[];
        first_publish_year?: number;
        number_of_pages_median?: number;
        isbn?: string[];
        language?: string[];
        cover_i?: number;
      }>;
    };
    const docs = body.docs ?? [];
    return docs
      .filter((d) => d.key && d.title)
      .map((d): CatalogCandidate => {
        const isbn13 = d.isbn?.find((i) => /^\d{13}$/.test(i));
        const c: CatalogCandidate = {
          source: "open_library",
          sourceId: d.key!,
          title: d.title!,
          authors: d.author_name ?? [],
        };
        if (isbn13) c.isbn13 = isbn13;
        if (d.number_of_pages_median && d.number_of_pages_median > 0) c.pageCount = d.number_of_pages_median;
        if (d.first_publish_year) c.publishedYear = d.first_publish_year;
        if (d.language?.[0]) c.languageCode = d.language[0];
        if (d.cover_i) c.coverUrl = `https://covers.openlibrary.org/b/id/${d.cover_i}-M.jpg`;
        c.rawUrl = `${env.OPEN_LIBRARY_BASE_URL}${d.key}`;
        return c;
      });
  } catch (err) {
    log.warn({ err }, "open library search failed");
    return [];
  }
}

/** Dedupe key: ISBN-13 if present, else normalised title+first-author. */
function mergeKey(c: CatalogCandidate): string {
  if (c.isbn13) return `isbn:${c.isbn13}`;
  const author = (c.authors[0] ?? "").toLowerCase().trim();
  return `ta:${c.title.toLowerCase().trim()}|${author}`;
}

/**
 * Search both sources and merge. Google Books wins on collisions (richer edition
 * metadata), but we backfill missing fields from the Open Library twin so a
 * merged candidate is as complete as possible.
 */
export async function searchCatalog(env: Env, log: Logger, p: SearchParams): Promise<CatalogCandidate[]> {
  const [google, openLib] = await Promise.all([
    searchGoogleBooks(env, log, p),
    searchOpenLibrary(env, log, p),
  ]);

  const merged = new Map<string, CatalogCandidate>();
  // Google first so it becomes the primary record on collision.
  for (const c of [...google, ...openLib]) {
    const key = mergeKey(c);
    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, c);
      continue;
    }
    // Backfill fields the primary is missing from the secondary source.
    existing.isbn13 ??= c.isbn13;
    existing.pageCount ??= c.pageCount;
    existing.publishedYear ??= c.publishedYear;
    existing.languageCode ??= c.languageCode;
    existing.coverUrl ??= c.coverUrl;
    if (existing.authors.length === 0 && c.authors.length > 0) existing.authors = c.authors;
  }

  return [...merged.values()].slice(0, p.limit);
}
