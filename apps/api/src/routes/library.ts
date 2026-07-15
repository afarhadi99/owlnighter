import type { FastifyInstance } from "fastify";
import { desc, eq } from "drizzle-orm";
import { schema } from "@owlnighter/db";
import {
  type AddLibraryBookRequest,
  type LibraryBook,
  type LibraryBookView,
  type LibraryBooksResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { badRequest, notFound } from "../plugins/errors.js";
import { requireUser } from "../plugins/auth.js";
import { register } from "./helpers.js";

export function registerLibraryRoutes(app: FastifyInstance, deps: Deps): void {
  register<never, LibraryBooksResponse>(app, deps, "listLibraryBooks", async ({ req }) => {
    const user = requireUser(req);
    // Inner-join public.books so each card carries the catalog identity (title,
    // authors, cover, grounding badge, length) — an inner join is correct here
    // because a user_books row can only exist for a book that was grounded first.
    const rows = await deps.db
      .select({
        id: schema.userBooks.id,
        bookId: schema.userBooks.bookId,
        status: schema.userBooks.status,
        currentPage: schema.userBooks.currentPage,
        targetNightlyPages: schema.userBooks.targetNightlyPages,
        title: schema.books.canonicalTitle,
        authors: schema.books.canonicalAuthor,
        coverUrl: schema.books.coverUrl,
        groundingStatus: schema.books.groundingStatus,
        pageCount: schema.books.pageCount,
      })
      .from(schema.userBooks)
      .innerJoin(schema.books, eq(schema.userBooks.bookId, schema.books.id))
      .where(eq(schema.userBooks.userId, user.id))
      .orderBy(desc(schema.userBooks.createdAt));
    const books = rows.map((r): LibraryBookView => {
      const b: LibraryBookView = {
        id: r.id,
        bookId: r.bookId,
        status: r.status as LibraryBookView["status"],
        title: r.title,
        authors: r.authors ?? [],
        groundingStatus: r.groundingStatus as LibraryBookView["groundingStatus"],
      };
      if (r.currentPage != null) b.currentPage = r.currentPage;
      if (r.targetNightlyPages != null) b.targetNightlyPages = r.targetNightlyPages;
      if (r.coverUrl != null) b.coverUrl = r.coverUrl;
      if (r.pageCount != null) b.pageCount = r.pageCount;
      return b;
    });
    return { books };
  });

  register<AddLibraryBookRequest, LibraryBook>(app, deps, "addLibraryBook", async ({ req, body }) => {
    const user = requireUser(req);

    // The book must exist (grounded) before it can be added to a library.
    const book = await deps.db
      .select({ id: schema.books.id })
      .from(schema.books)
      .where(eq(schema.books.id, body.bookId))
      .limit(1);
    if (!book[0]) throw notFound("Book not found. Ground it first via POST /v1/books/ground.");

    // Single fetch of the caller's library rows — reused for both the
    // reactivate-existing-entry check and the max-books-per-user limit below.
    const userBooksRows = await deps.db
      .select()
      .from(schema.userBooks)
      .where(eq(schema.userBooks.userId, user.id));
    const existingRow = userBooksRows.find((r) => r.bookId === body.bookId);

    if (existingRow) {
      await deps.db
        .update(schema.userBooks)
        .set({ status: "active", targetNightlyPages: body.targetNightlyPages, timezone: body.timezone })
        .where(eq(schema.userBooks.id, existingRow.id));
      return {
        id: existingRow.id,
        bookId: existingRow.bookId,
        status: "active",
        ...(existingRow.currentPage != null ? { currentPage: existingRow.currentPage } : {}),
        targetNightlyPages: body.targetNightlyPages,
      };
    }

    const maxBooks = await deps.settings.get("max_books_per_user", 3);
    const activeCount = userBooksRows.filter((r) => r.status === "active").length;
    if (activeCount >= maxBooks) {
      throw badRequest(
        `You've reached the limit of ${maxBooks} active books. Pause or finish one before adding another.`,
      );
    }

    const inserted = await deps.db
      .insert(schema.userBooks)
      .values({
        userId: user.id,
        bookId: body.bookId,
        status: "active",
        targetNightlyPages: body.targetNightlyPages,
        preferredReadingTimeLocal: body.preferredReadingTimeLocal ?? null,
        timezone: body.timezone,
      })
      .returning({ id: schema.userBooks.id, currentPage: schema.userBooks.currentPage });
    const row = inserted[0]!;
    return {
      id: row.id,
      bookId: body.bookId,
      status: "active",
      ...(row.currentPage != null ? { currentPage: row.currentPage } : {}),
      targetNightlyPages: body.targetNightlyPages,
    };
  });
}
