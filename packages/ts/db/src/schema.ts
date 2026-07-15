import {
  boolean,
  date,
  integer,
  jsonb,
  numeric,
  pgTable,
  text,
  time,
  timestamp,
  uuid,
  vector,
} from "drizzle-orm/pg-core";

/**
 * Typed mirror of infra/sql. The SQL files are the canonical migration source;
 * this schema exists for type-safe queries in the API/jobs.
 */

export const profiles = pgTable("profiles", {
  id: uuid("id").primaryKey(),
  displayName: text("display_name"),
  avatarUrl: text("avatar_url"),
  locale: text("locale").notNull().default("en-US"),
  isAdmin: boolean("is_admin").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const books = pgTable("books", {
  id: uuid("id").primaryKey().defaultRandom(),
  canonicalTitle: text("canonical_title").notNull(),
  canonicalAuthor: text("canonical_author").array().notNull().default([]),
  isbn13: text("isbn13"),
  googleBooksId: text("google_books_id"),
  openLibraryKey: text("open_library_key"),
  editionLabel: text("edition_label"),
  languageCode: text("language_code"),
  publishedYear: integer("published_year"),
  pageCount: integer("page_count"),
  coverUrl: text("cover_url"),
  metadataConfidence: numeric("metadata_confidence").notNull().default("0.0"),
  groundingStatus: text("grounding_status").notNull().default("pending"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const userBooks = pgTable("user_books", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  bookId: uuid("book_id").notNull(),
  status: text("status").notNull().default("active"),
  currentPage: integer("current_page"),
  targetNightlyPages: integer("target_nightly_pages"),
  preferredReadingTimeLocal: time("preferred_reading_time_local"),
  timezone: text("timezone").notNull().default("UTC"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const readingPlans = pgTable("reading_plans", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  bookId: uuid("book_id").notNull(),
  provider: text("provider").notNull(),
  providerModel: text("provider_model").notNull(),
  planVersion: integer("plan_version").notNull().default(1),
  nightlyGoalPages: integer("nightly_goal_pages").notNull(),
  pacingMode: text("pacing_mode").notNull(),
  startsOn: date("starts_on").notNull(),
  endsOn: date("ends_on"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const readingPlanSteps = pgTable("reading_plan_steps", {
  id: uuid("id").primaryKey().defaultRandom(),
  planId: uuid("plan_id").notNull(),
  stepIndex: integer("step_index").notNull(),
  pageStart: integer("page_start"),
  pageEnd: integer("page_end"),
  chapterHint: text("chapter_hint"),
  title: text("title").notNull(),
  shortPrompt: text("short_prompt"),
  quizMode: text("quiz_mode").notNull(),
  ttsAssetId: uuid("tts_asset_id"),
  unlocksAt: timestamp("unlocks_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const readingSessions = pgTable("reading_sessions", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  stepId: uuid("step_id").notNull(),
  startedAt: timestamp("started_at", { withTimezone: true }).notNull().defaultNow(),
  completedAt: timestamp("completed_at", { withTimezone: true }),
  pagesRead: integer("pages_read"),
});

export const quizInstances = pgTable("quiz_instances", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  stepId: uuid("step_id").notNull(),
  sessionId: uuid("session_id"),
  quizMode: text("quiz_mode").notNull(),
  provider: text("provider").notNull(),
  providerModel: text("provider_model").notNull(),
  confidence: numeric("confidence").notNull().default("0.0"),
  // Set by an admin (0003) to retire a bad quiz; skipped when reusing a step's quiz.
  invalidatedAt: timestamp("invalidated_at", { withTimezone: true }),
  invalidationReason: text("invalidation_reason"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const quizQuestions = pgTable("quiz_questions", {
  id: uuid("id").primaryKey().defaultRandom(),
  quizId: uuid("quiz_id").notNull(),
  ordinal: integer("ordinal").notNull(),
  kind: text("kind").notNull(),
  prompt: text("prompt").notNull(),
  options: jsonb("options"),
  correctAnswer: text("correct_answer").notNull(),
  explanation: text("explanation"),
  sourceCitationIndex: integer("source_citation_index"),
});

export const quizAttempts = pgTable("quiz_attempts", {
  id: uuid("id").primaryKey().defaultRandom(),
  quizId: uuid("quiz_id").notNull(),
  userId: uuid("user_id").notNull(),
  answers: jsonb("answers").notNull(),
  correctCount: integer("correct_count").notNull(),
  totalCount: integer("total_count").notNull(),
  passed: boolean("passed").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const streakDays = pgTable("streak_days", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  day: date("day").notNull(),
  xp: integer("xp").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const pushTokens = pgTable("push_tokens", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  token: text("token").notNull().unique(),
  platform: text("platform").notNull(),
  appVersion: text("app_version"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const notificationPreferences = pgTable("notification_preferences", {
  userId: uuid("user_id").primaryKey(),
  nightlyReminder: boolean("nightly_reminder").notNull().default(true),
  streakWarning: boolean("streak_warning").notNull().default(true),
  reminderTimeLocal: time("reminder_time_local").notNull().default("20:30"),
  timezone: text("timezone").notNull().default("UTC"),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const ttsAssets = pgTable("tts_assets", {
  id: uuid("id").primaryKey().defaultRandom(),
  assetKey: text("asset_key").notNull().unique(),
  provider: text("provider").notNull().default("deepgram"),
  voiceModel: text("voice_model").notNull(),
  locale: text("locale").notNull().default("en"),
  storagePath: text("storage_path").notNull(),
  durationMs: integer("duration_ms"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

// ---- Grounding & provenance ----
export const bookGroundingRuns = pgTable("book_grounding_runs", {
  id: uuid("id").primaryKey().defaultRandom(),
  bookId: uuid("book_id").notNull(),
  provider: text("provider").notNull(),
  providerModel: text("provider_model").notNull(),
  runKind: text("run_kind").notNull(),
  inputHash: text("input_hash").notNull(),
  status: text("status").notNull().default("running"),
  citationsJson: jsonb("citations_json").notNull().default([]),
  rawResult: jsonb("raw_result"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  completedAt: timestamp("completed_at", { withTimezone: true }),
});

export const bookGroundingSources = pgTable("book_grounding_sources", {
  id: uuid("id").primaryKey().defaultRandom(),
  groundingRunId: uuid("grounding_run_id").notNull(),
  sourceType: text("source_type").notNull(),
  sourceUrl: text("source_url"),
  sourceTitle: text("source_title"),
  sourceSnippet: text("source_snippet"),
  citationIndex: integer("citation_index").notNull(),
  trustScore: numeric("trust_score").notNull().default("0.5"),
});

export const bookGroundingFacts = pgTable("book_grounding_facts", {
  id: uuid("id").primaryKey().defaultRandom(),
  groundingRunId: uuid("grounding_run_id").notNull(),
  factType: text("fact_type").notNull(),
  key: text("key").notNull(),
  valueJson: jsonb("value_json").notNull(),
  confidence: numeric("confidence").notNull(),
  provenanceSourceIds: uuid("provenance_source_ids").array().notNull().default([]),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const bookGroundingEmbeddings = pgTable("book_grounding_embeddings", {
  id: uuid("id").primaryKey().defaultRandom(),
  factId: uuid("fact_id").notNull(),
  embedding: vector("embedding", { dimensions: 768 }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const quizGenerationRuns = pgTable("quiz_generation_runs", {
  id: uuid("id").primaryKey().defaultRandom(),
  quizId: uuid("quiz_id"),
  provider: text("provider").notNull(),
  providerModel: text("provider_model").notNull(),
  inputHash: text("input_hash").notNull(),
  status: text("status").notNull().default("running"),
  attempts: integer("attempts").notNull().default(1),
  rawResult: jsonb("raw_result"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const adminAccounts = pgTable("admin_accounts", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull(),
  passwordHash: text("password_hash").notNull(),
  status: text("status").notNull().default("pending"),
  isAdmin: boolean("is_admin").notNull().default(false),
  approvedBy: uuid("approved_by"),
  approvedAt: timestamp("approved_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const adminSessions = pgTable("admin_sessions", {
  id: uuid("id").primaryKey().defaultRandom(),
  adminAccountId: uuid("admin_account_id").notNull(),
  tokenHash: text("token_hash").notNull().unique(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const appSettings = pgTable("app_settings", {
  key: text("key").primaryKey(),
  value: jsonb("value").notNull(),
  isSecret: boolean("is_secret").notNull().default(false),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  updatedBy: uuid("updated_by"),
});
