// Idempotent demo/seed data for the owlnighter platform.
//
// Populates a believable cross-section (readers, books across grounding states,
// reading plans + steps, sessions, quizzes, attempts, streaks, and grounding
// provenance) so the admin panel and mobile app show real distributions instead
// of a near-empty DB.
//
// Safe to re-run: every row uses a deterministic UUID (derived via a namespaced
// SHA-1, uuid-v5 style) and every insert is ON CONFLICT DO NOTHING, so a second
// run adds nothing. It ADDS to the dataset — it never wipes the fixed DEV user
// (00000000-0000-4000-8000-0000000000de) or anything else.
//
// Usage: DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:53322/postgres \
//        node scripts/seed-demo-data.mjs
import { createHash } from "node:crypto";
import postgres from "postgres";

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

// ---- deterministic UUID (uuid v5-ish: sha1 of a namespaced name) -------------
const NS = "owlnighter-demo-seed";
function duid(name) {
  const h = createHash("sha1").update(`${NS}:${name}`).digest();
  const b = Buffer.from(h.subarray(0, 16));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 10
  const hex = b.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

// ---- date helpers: anchored (NOT now()) so re-runs are byte-identical --------
const ANCHOR = new Date("2026-07-18T00:00:00Z");
function dayISO(daysFromAnchor) {
  const d = new Date(ANCHOR.getTime() + daysFromAnchor * 86400000);
  return d.toISOString().slice(0, 10);
}
function ts(daysFromAnchor, hour = 20, minute = 30) {
  return new Date(ANCHOR.getTime() + daysFromAnchor * 86400000 + (hour * 60 + minute) * 60000);
}

// ---- demo users -------------------------------------------------------------
const USERS = [
  { key: "maya", name: "Maya Chen", email: "maya.chen@demo.owlnighter.local", locale: "en-US", tz: "America/Los_Angeles" },
  { key: "liam", name: "Liam O'Connor", email: "liam.oconnor@demo.owlnighter.local", locale: "en-GB", tz: "Europe/London" },
  { key: "sofia", name: "Sofia Rossi", email: "sofia.rossi@demo.owlnighter.local", locale: "it-IT", tz: "Europe/Rome" },
  { key: "noah", name: "Noah Kim", email: "noah.kim@demo.owlnighter.local", locale: "ko-KR", tz: "Asia/Seoul" },
  { key: "amara", name: "Amara Okafor", email: "amara.okafor@demo.owlnighter.local", locale: "en-NG", tz: "Africa/Lagos" },
  { key: "lucas", name: "Lucas Silva", email: "lucas.silva@demo.owlnighter.local", locale: "pt-BR", tz: "America/Sao_Paulo" },
];
const uid = (key) => duid(`user:${key}`);

// ---- demo books: spread across grounding states + confidence buckets --------
// bucket thresholds (API defaults): >=0.85 auto_accepted, 0.6-0.84 needs_review, <0.6 limited
const BOOKS = [
  // grounded / high confidence (auto_accepted)
  { key: "pride", title: "Pride and Prejudice", authors: ["Jane Austen"], isbn: "9780141439518", year: 1813, pages: 480, status: "grounded", conf: "0.970", ground: true },
  { key: "1984", title: "1984", authors: ["George Orwell"], isbn: "9780451524935", year: 1949, pages: 328, status: "grounded", conf: "0.940", ground: true },
  { key: "gatsby", title: "The Great Gatsby", authors: ["F. Scott Fitzgerald"], isbn: "9780743273565", year: 1925, pages: 180, status: "grounded", conf: "0.910", ground: true },
  { key: "mockingbird", title: "To Kill a Mockingbird", authors: ["Harper Lee"], isbn: "9780061120084", year: 1960, pages: 336, status: "grounded", conf: "0.880", ground: true },
  // partial / mid confidence (needs_review)
  { key: "midnight", title: "The Midnight Library", authors: ["Matt Haig"], isbn: "9780525559474", year: 2020, pages: 304, status: "partial", conf: "0.780", ground: true },
  { key: "hailmary", title: "Project Hail Mary", authors: ["Andy Weir"], isbn: "9780593135204", year: 2021, pages: 496, status: "partial", conf: "0.720" },
  { key: "educated", title: "Educated", authors: ["Tara Westover"], isbn: "9780399590504", year: 2018, pages: 334, status: "partial", conf: "0.660" },
  // blocked / low confidence (limited)
  { key: "achilles", title: "The Song of Achilles", authors: ["Madeline Miller"], isbn: "9781408821985", year: 2011, pages: 352, status: "blocked", conf: "0.520" },
  { key: "klara", title: "Klara and the Sun", authors: ["Kazuo Ishiguro"], isbn: "9780571364879", year: 2021, pages: 320, status: "blocked", conf: "0.410" },
  // pending (not yet grounded)
  { key: "tomorrow", title: "Tomorrow, and Tomorrow, and Tomorrow", authors: ["Gabrielle Zevin"], isbn: "9780593321201", year: 2022, pages: 416, status: "pending", conf: "0.280" },
];
const bid = (key) => duid(`book:${key}`);
const cover = (isbn) => `https://covers.openlibrary.org/b/isbn/${isbn}-L.jpg`;

// ---- reading plans: (user, book) with multi-step, varied progress -----------
const PLANS = [
  { user: "maya", book: "pride", provider: "ai_tutor_api", model: "ai-tutor-v2", pacing: "standard", nightly: 20, steps: 6, completed: 4, mode: "grounded", startDaysAgo: 9, ub: "active" },
  { user: "maya", book: "1984", provider: "gemini", model: "gemini-2.0-flash", pacing: "intensive", nightly: 30, steps: 5, completed: 5, mode: "grounded", startDaysAgo: 22, ub: "completed" },
  { user: "liam", book: "gatsby", provider: "gemini", model: "gemini-2.0-flash", pacing: "gentle", nightly: 12, steps: 5, completed: 2, mode: "grounded", startDaysAgo: 5, ub: "active" },
  { user: "sofia", book: "midnight", provider: "groq", model: "llama-3.3-70b-versatile", pacing: "standard", nightly: 18, steps: 5, completed: 3, mode: "preview", startDaysAgo: 7, ub: "active" },
  { user: "noah", book: "hailmary", provider: "openrouter", model: "anthropic/claude-3.5-sonnet", pacing: "standard", nightly: 22, steps: 6, completed: 1, mode: "preview", startDaysAgo: 3, ub: "active" },
  { user: "amara", book: "mockingbird", provider: "ai_tutor_api", model: "ai-tutor-v2", pacing: "gentle", nightly: 10, steps: 5, completed: 2, mode: "grounded", startDaysAgo: 13, ub: "paused" },
  { user: "lucas", book: "educated", provider: "gemini", model: "gemini-2.0-flash", pacing: "intensive", nightly: 28, steps: 6, completed: 6, mode: "user_text", startDaysAgo: 16, ub: "completed" },
  { user: "liam", book: "achilles", provider: "groq", model: "llama-3.3-70b-versatile", pacing: "standard", nightly: 16, steps: 4, completed: 1, mode: "fallback", startDaysAgo: 2, ub: "active" },
];

// Extra standalone user_books (browsing / not yet planned) to vary the library.
const EXTRA_UB = [
  { user: "noah", book: "klara", status: "active", page: 0 },
  { user: "sofia", book: "tomorrow", status: "archived", page: 40 },
  { user: "amara", book: "achilles", status: "paused", page: 88 },
];

function buildQuestions(book, stepIdx) {
  const t = book.title;
  return [
    {
      kind: "multiple_choice",
      prompt: `In this section of "${t}", which development most directly advances the central conflict?`,
      options: ["A turning point in a key relationship", "An unrelated flashback", "A change of narrator", "A footnote from the editor"],
      correct: "A turning point in a key relationship",
      explanation: "The section pivots on the relationship shift that reframes the stakes.",
      citation: 0,
    },
    {
      kind: "true_false",
      prompt: `The events in step ${stepIdx + 1} take place primarily from the protagonist's point of view.`,
      options: ["True", "False"],
      correct: "True",
      explanation: "The narration stays close to the protagonist throughout this stretch.",
      citation: 1,
    },
    {
      kind: "multiple_choice",
      prompt: `Which theme is emphasized most in these pages of "${t}"?`,
      options: ["Belonging and identity", "Interplanetary trade law", "Competitive baking", "Naval logistics"],
      correct: "Belonging and identity",
      explanation: "Identity and belonging recur across the passage's imagery and dialogue.",
      citation: 0,
    },
    {
      kind: "short_answer",
      prompt: `Name one consequence the protagonist faces by the end of this section.`,
      options: null,
      correct: "A strained relationship / a difficult choice",
      explanation: "Accept any answer citing a relational cost or a forced decision.",
      citation: 2,
    },
  ];
}

const sql = postgres(url, { max: 1 });

async function tableCounts() {
  const rows = await sql`
    select relname, n_live_tup as n from pg_stat_user_tables
    where relname in (
      'profiles','books','user_books','reading_plans','reading_plan_steps',
      'reading_sessions','quiz_instances','quiz_questions','quiz_attempts',
      'streak_days','book_grounding_runs','book_grounding_facts','book_grounding_sources'
    ) order by relname`;
  return Object.fromEntries(rows.map((r) => [r.relname, Number(r.n)]));
}

try {
  console.log("=== counts BEFORE ===");
  console.table(await tableCounts());

  // 1) auth.users + 2) profiles
  for (const u of USERS) {
    await sql`
      insert into auth.users (id, email, aud, role, email_confirmed_at, created_at, updated_at)
      values (${uid(u.key)}, ${u.email}, 'authenticated', 'authenticated', ${ts(-30, 12, 0)}, ${ts(-30, 12, 0)}, ${ts(-30, 12, 0)})
      on conflict (id) do nothing`;
    await sql`
      insert into public.profiles (id, display_name, locale, is_admin, created_at, updated_at)
      values (${uid(u.key)}, ${u.name}, ${u.locale}, false, ${ts(-30, 12, 0)}, ${ts(-1, 12, 0)})
      on conflict (id) do nothing`;
  }

  // 3) books
  for (const b of BOOKS) {
    await sql`
      insert into public.books
        (id, canonical_title, canonical_author, isbn13, open_library_key, language_code,
         published_year, page_count, cover_url, metadata_confidence, grounding_status, created_at, updated_at)
      values
        (${bid(b.key)}, ${b.title}, ${b.authors}, ${b.isbn}, ${"/isbn/" + b.isbn}, 'en',
         ${b.year}, ${b.pages}, ${cover(b.isbn)}, ${b.conf}, ${b.status}, ${ts(-25, 9, 0)}, ${ts(-2, 9, 0)})
      on conflict (id) do nothing`;
  }

  // 4) grounding provenance for books flagged ground:true
  for (const b of BOOKS.filter((x) => x.ground)) {
    const runId = duid(`grun:${b.key}`);
    await sql`
      insert into public.book_grounding_runs
        (id, book_id, provider, provider_model, run_kind, input_hash, status, citations_json, raw_result, created_at, completed_at)
      values
        (${runId}, ${bid(b.key)}, 'gemini', 'gemini-2.0-flash', 'enrich',
         ${"sha256:" + duid(`hash:${b.key}`).replace(/-/g, "")}, 'succeeded',
         ${sql.json([{ index: 0, title: "Google Books volume" }, { index: 1, title: "Open Library edition" }, { index: 2, title: "Wikipedia article" }])},
         ${sql.json({ note: "demo enrichment run", title: b.title })}, ${ts(-24, 9, 0)}, ${ts(-24, 9, 5)})
      on conflict (id) do nothing`;

    const sources = [
      { idx: 0, type: "google_books", url: `https://books.google.com/books?isbn=${b.isbn}`, title: `${b.title} — Google Books`, snippet: `${b.pages} pages. First published ${b.year}.`, trust: "0.900" },
      { idx: 1, type: "open_library", url: `https://openlibrary.org/isbn/${b.isbn}`, title: `${b.title} — Open Library`, snippet: `Edition record for ISBN ${b.isbn}.`, trust: "0.850" },
      { idx: 2, type: "web", url: `https://en.wikipedia.org/wiki/${encodeURIComponent(b.title.replace(/ /g, "_"))}`, title: `${b.title} — Wikipedia`, snippet: `Overview, themes, and reception of ${b.title}.`, trust: "0.700" },
    ];
    const srcIds = {};
    for (const s of sources) {
      const sid = duid(`gsrc:${b.key}:${s.idx}`);
      srcIds[s.idx] = sid;
      await sql`
        insert into public.book_grounding_sources
          (id, grounding_run_id, source_type, source_url, source_title, source_snippet, citation_index, trust_score)
        values (${sid}, ${runId}, ${s.type}, ${s.url}, ${s.title}, ${s.snippet}, ${s.idx}, ${s.trust})
        on conflict (id) do nothing`;
    }

    const facts = [
      { type: "page_count", key: "page_count", value: { pages: b.pages }, conf: b.conf, prov: [0, 1] },
      { type: "theme", key: "primary_theme", value: { theme: "identity and belonging" }, conf: "0.750", prov: [2] },
      { type: "chapter_map", key: "chapters", value: { chapters: Math.max(8, Math.round(b.pages / 30)) }, conf: "0.680", prov: [0, 2] },
    ];
    for (const f of facts) {
      const fid = duid(`gfact:${b.key}:${f.key}`);
      await sql`
        insert into public.book_grounding_facts
          (id, grounding_run_id, fact_type, key, value_json, confidence, provenance_source_ids, created_at)
        values (${fid}, ${runId}, ${f.type}, ${f.key}, ${sql.json(f.value)}, ${f.conf},
                ${f.prov.map((i) => srcIds[i])}, ${ts(-24, 9, 6)})
        on conflict (id) do nothing`;
    }
  }

  // 5) user_books from plans + extras
  for (const p of PLANS) {
    const b = BOOKS.find((x) => x.key === p.book);
    const page = p.ub === "completed" ? b.pages : Math.min(b.pages, p.completed * p.nightly);
    await sql`
      insert into public.user_books
        (id, user_id, book_id, status, current_page, target_nightly_pages, preferred_reading_time_local, timezone, created_at)
      values (${duid(`ub:${p.user}:${p.book}`)}, ${uid(p.user)}, ${bid(p.book)}, ${p.ub}, ${page},
              ${p.nightly}, '20:30', ${USERS.find((u) => u.key === p.user).tz}, ${ts(-p.startDaysAgo, 19, 0)})
      on conflict (user_id, book_id) do nothing`;
  }
  for (const e of EXTRA_UB) {
    await sql`
      insert into public.user_books
        (id, user_id, book_id, status, current_page, target_nightly_pages, timezone, created_at)
      values (${duid(`ub:${e.user}:${e.book}`)}, ${uid(e.user)}, ${bid(e.book)}, ${e.status}, ${e.page},
              15, ${USERS.find((u) => u.key === e.user).tz}, ${ts(-6, 19, 0)})
      on conflict (user_id, book_id) do nothing`;
  }

  // 6-11) plans, steps, sessions, quizzes, questions, attempts, streaks
  const streakAcc = new Map(); // `${user}|${day}` -> xp
  let invalidatedOnce = false;

  for (const p of PLANS) {
    const b = BOOKS.find((x) => x.key === p.book);
    const planId = duid(`plan:${p.user}:${p.book}`);
    const endsOn = p.ub === "completed" ? dayISO(-p.startDaysAgo + p.steps) : null;
    await sql`
      insert into public.reading_plans
        (id, user_id, book_id, provider, provider_model, plan_version, nightly_goal_pages, pacing_mode, starts_on, ends_on, created_at)
      values (${planId}, ${uid(p.user)}, ${bid(p.book)}, ${p.provider}, ${p.model}, 1, ${p.nightly}, ${p.pacing},
              ${dayISO(-p.startDaysAgo)}, ${endsOn}, ${ts(-p.startDaysAgo, 18, 0)})
      on conflict (id) do nothing`;

    for (let k = 0; k < p.steps; k++) {
      const stepId = duid(`step:${p.user}:${p.book}:${k}`);
      const pageStart = k * p.nightly + 1;
      const pageEnd = Math.min(b.pages, (k + 1) * p.nightly);
      const dayOffset = -p.startDaysAgo + k;
      await sql`
        insert into public.reading_plan_steps
          (id, plan_id, step_index, page_start, page_end, chapter_hint, title, short_prompt, quiz_mode, unlocks_at, created_at)
        values (${stepId}, ${planId}, ${k}, ${pageStart}, ${pageEnd},
                ${`pp. ${pageStart}–${pageEnd}`}, ${`Night ${k + 1}: pages ${pageStart}–${pageEnd}`},
                ${`Read to page ${pageEnd} of "${b.title}", then take a short quiz.`},
                ${p.mode}, ${ts(dayOffset, 18, 0)}, ${ts(-p.startDaysAgo, 18, 0)})
        on conflict (id) do nothing`;

      if (k >= p.completed) continue; // available/locked steps: no session/quiz yet

      // reading session (completed)
      const sessId = duid(`sess:${p.user}:${p.book}:${k}`);
      await sql`
        insert into public.reading_sessions (id, user_id, step_id, started_at, completed_at, pages_read)
        values (${sessId}, ${uid(p.user)}, ${stepId}, ${ts(dayOffset, 20, 30)}, ${ts(dayOffset, 21, 5)}, ${pageEnd - pageStart + 1})
        on conflict (id) do nothing`;

      // quiz instance
      const quizId = duid(`quiz:${p.user}:${p.book}:${k}`);
      const confByMode = p.mode === "grounded" ? "0.900" : p.mode === "user_text" ? "0.850" : p.mode === "preview" ? "0.700" : "0.500";
      // Invalidate exactly one quiz to exercise the Quiz-QA invalidation path.
      const invalidate = !invalidatedOnce && p.user === "sofia" && k === 0;
      if (invalidate) invalidatedOnce = true;
      await sql`
        insert into public.quiz_instances
          (id, user_id, step_id, session_id, quiz_mode, provider, provider_model, confidence, invalidated_at, invalidation_reason, created_at)
        values (${quizId}, ${uid(p.user)}, ${stepId}, ${sessId}, ${p.mode}, ${p.provider}, ${p.model}, ${confByMode},
                ${invalidate ? ts(dayOffset, 22, 0) : null}, ${invalidate ? "Ambiguous question flagged in QA review" : null}, ${ts(dayOffset, 21, 6)})
        on conflict (id) do nothing`;

      // questions
      const qs = buildQuestions(b, k);
      for (let o = 0; o < qs.length; o++) {
        const q = qs[o];
        await sql`
          insert into public.quiz_questions
            (id, quiz_id, ordinal, kind, prompt, options, correct_answer, explanation, source_citation_index)
          values (${duid(`qq:${p.user}:${p.book}:${k}:${o}`)}, ${quizId}, ${o}, ${q.kind}, ${q.prompt},
                  ${q.options ? sql.json(q.options) : null}, ${q.correct}, ${q.explanation}, ${q.citation})
          on conflict (id) do nothing`;
      }

      // attempts: mostly pass; a deterministic subset fails first then retries to a pass.
      const total = qs.length;
      const failsFirst = (k % 4 === 2); // some steps start with a failed attempt
      if (failsFirst) {
        await sql`
          insert into public.quiz_attempts (id, quiz_id, user_id, answers, correct_count, total_count, passed, created_at)
          values (${duid(`att:${p.user}:${p.book}:${k}:0`)}, ${quizId}, ${uid(p.user)},
                  ${sql.json(["An unrelated flashback", "False", "Naval logistics", "n/a"])}, 1, ${total}, false, ${ts(dayOffset, 21, 10)})
          on conflict (id) do nothing`;
      }
      const correct = failsFirst ? total - 1 : total; // retry lands 3/4 or full marks
      const passed = correct * 2 >= total; // pass threshold ~50%
      await sql`
        insert into public.quiz_attempts (id, quiz_id, user_id, answers, correct_count, total_count, passed, created_at)
        values (${duid(`att:${p.user}:${p.book}:${k}:1`)}, ${quizId}, ${uid(p.user)},
                ${sql.json(["A turning point in a key relationship", "True", "Belonging and identity", "A strained relationship"])},
                ${correct}, ${total}, ${passed}, ${ts(dayOffset, 21, 15)})
        on conflict (id) do nothing`;

      // streak day accumulation (one completed step per day per user)
      const key = `${p.user}|${dayISO(dayOffset)}`;
      streakAcc.set(key, (streakAcc.get(key) ?? 0) + 20 + correct * 10);
    }
  }

  // 12) streak_days (deterministic id per user+day, unique constraint anyway)
  for (const [key, xp] of streakAcc) {
    const [user, day] = key.split("|");
    await sql`
      insert into public.streak_days (id, user_id, day, xp, created_at)
      values (${duid(`streak:${user}:${day}`)}, ${uid(user)}, ${day}, ${xp}, ${new Date(day + "T23:59:00Z")})
      on conflict (user_id, day) do nothing`;
  }

  console.log("\n=== counts AFTER ===");
  console.table(await tableCounts());

  const demoUsers = await sql`select count(*)::int n from profiles where id = any(${USERS.map((u) => uid(u.key))})`;
  const demoBooks = await sql`select count(*)::int n from books where id = any(${BOOKS.map((b) => bid(b.key))})`;
  console.log(`\n✓ Demo users present: ${demoUsers[0].n}/${USERS.length}, demo books present: ${demoBooks[0].n}/${BOOKS.length}`);
  console.log("✓ Seed complete (idempotent — re-run adds nothing).");
} finally {
  await sql.end();
}
