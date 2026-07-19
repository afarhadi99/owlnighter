#!/usr/bin/env node
// ============================================================================
// owlnighter — from-scratch developer setup orchestrator
//
// Runs once Node exists (the bootstrap wrappers scripts/setup.sh / setup.ps1
// make sure of that). Zero new dependencies — only node: builtins.
//
// What it does, in order:
//   1. Preflight   — detect node / pnpm / docker / flutter, print a ✓/✗ table
//                    and per-OS install hints for anything missing.
//   2. Env + keys  — scaffold .env from .env.example, walk the user through the
//                    provider API keys, set DATABASE_URL to the local Postgres.
//   3. Admin pwds  — the 3 admin-panel logins (SEED_ADMIN_PASSWORD_*): generate
//                    strong ones (printed once) or let the user type their own.
//   4. Install     — pnpm install.
//   5. Database    — start a pgvector Postgres container, wait until ready, then
//                    apply-local.mjs (dev shim → migrations → dev seed),
//                    seed:admin, seed:demo. Every step is idempotent.
//   6. Finish      — print how to run the API / admin / mobile app.
//
// Flags:
//   --non-interactive, --yes   Scaffold .env from .env.example with no prompts.
//   --skip-db                  Skip the Docker/Postgres/seed steps.
//   --skip-install             Skip `pnpm install`.
//   --skip-flutter-check       Don't probe for the Flutter SDK.
//
// Test/override env vars (used by the automated from-scratch test; harmless in
// normal use):
//   SETUP_ENV_FILE     Path to the .env to write        (default <repo>/.env)
//   SETUP_DB_PORT      Host port for the DB container    (default 55432)
//   SETUP_DB_CONTAINER Docker container name             (default owlnighter-db)
//   SETUP_DB_IMAGE     Postgres image                    (default pgvector/pgvector:pg16)
//   SEED_ADMIN_PASSWORD_RCOHEN / _NKUKAJ / _AFARHADI     Prefill admin passwords
//
// Secrets are ONLY ever written to .env (gitignored). Provider keys are never
// echoed back. The 3 generated admin passwords are the sole thing printed, once.
// ============================================================================

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync, copyFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { randomBytes } from "node:crypto";
import { createInterface } from "node:readline";

// --- paths -------------------------------------------------------------------
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");
const envExample = join(repoRoot, ".env.example");
const envFile = process.env.SETUP_ENV_FILE
  ? resolve(process.env.SETUP_ENV_FILE)
  : join(repoRoot, ".env");
const dbScripts = join(repoRoot, "packages", "ts", "db", "scripts");

// --- flags -------------------------------------------------------------------
const argv = new Set(process.argv.slice(2));
const NON_INTERACTIVE = argv.has("--non-interactive") || argv.has("--yes") || argv.has("-y");
const SKIP_DB = argv.has("--skip-db");
const SKIP_INSTALL = argv.has("--skip-install");
const SKIP_FLUTTER = argv.has("--skip-flutter-check");

// --- db config (overridable for testing) ------------------------------------
const DB_PORT = process.env.SETUP_DB_PORT || "55432";
const DB_CONTAINER = process.env.SETUP_DB_CONTAINER || "owlnighter-db";
const DB_IMAGE = process.env.SETUP_DB_IMAGE || "pgvector/pgvector:pg16";
const DATABASE_URL = `postgresql://postgres:postgres@127.0.0.1:${DB_PORT}/postgres`;

const isWin = process.platform === "win32";

// --- tiny pretty helpers -----------------------------------------------------
const c = {
  reset: "\x1b[0m", bold: "\x1b[1m", dim: "\x1b[2m",
  green: "\x1b[32m", red: "\x1b[31m", yellow: "\x1b[33m", cyan: "\x1b[36m",
};
const ok = (s) => `${c.green}${s}${c.reset}`;
const bad = (s) => `${c.red}${s}${c.reset}`;
const warn = (s) => `${c.yellow}${s}${c.reset}`;
function heading(n, title) {
  console.log(`\n${c.bold}${c.cyan}${n}. ${title}${c.reset}`);
}

// --- process helpers ---------------------------------------------------------
// Tool invocations (docker/pnpm/flutter) go through the shell on Windows so
// .cmd/.exe shims resolve; node script runs use the absolute node binary.
function runTool(cmd, args = [], opts = {}) {
  return spawnSync(cmd, args, { stdio: "inherit", shell: isWin, ...opts });
}
function capTool(cmd, args = []) {
  return spawnSync(cmd, args, { encoding: "utf8", shell: isWin });
}
function runNode(scriptAbs, extraEnv = {}) {
  return spawnSync(process.execPath, [scriptAbs], {
    stdio: "inherit",
    cwd: repoRoot,
    env: { ...process.env, ...extraEnv },
  });
}
// `docker` is a real executable (not a .cmd shim), so we call it WITHOUT a shell.
// That matters on Windows: shell:true concatenates args and would split a psql
// SQL string on its spaces. shell:false passes each arg through intact.
function runDocker(args = [], opts = {}) {
  return spawnSync("docker", args, { stdio: "inherit", shell: false, ...opts });
}
function capDocker(args = []) {
  return spawnSync("docker", args, { encoding: "utf8", shell: false });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// --- .env parse / edit -------------------------------------------------------
function parseEnv(text) {
  const out = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=(.*)$/);
    if (m) out[m[1]] = m[2];
  }
  return out;
}
// Replace KEY=... (first occurrence) or append if absent. Value written raw.
function setEnvVar(text, key, value) {
  const re = new RegExp(`^(\\s*${key}\\s*=).*$`, "m");
  if (re.test(text)) return text.replace(re, `$1${value}`);
  const nl = text.endsWith("\n") || text === "" ? "" : "\n";
  return `${text}${nl}${key}=${value}\n`;
}

// --- readline ----------------------------------------------------------------
let rl = null;
function ask(question) {
  if (!rl) rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((res) => rl.question(question, (a) => res(a)));
}
async function askYesNo(question, def = true) {
  if (NON_INTERACTIVE) return def;
  const hint = def ? "[Y/n]" : "[y/N]";
  const a = (await ask(`${question} ${hint} `)).trim().toLowerCase();
  if (a === "") return def;
  return a === "y" || a === "yes";
}

// --- password generation -----------------------------------------------------
function strongPassword() {
  // URL-safe, no ambiguous chars, ~20 chars of entropy.
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  const bytes = randomBytes(20);
  let s = "";
  for (const b of bytes) s += alphabet[b % alphabet.length];
  return s;
}

// ============================================================================
// 1. PREFLIGHT
// ============================================================================
function installHint(tool) {
  const mac = "macOS", lin = "Linux", win = "Windows";
  const os = isWin ? win : process.platform === "darwin" ? mac : lin;
  const hints = {
    pnpm: {
      [mac]: "corepack enable   (ships with Node ≥16)",
      [lin]: "corepack enable   (ships with Node ≥16)",
      [win]: "corepack enable   (ships with Node ≥16)",
    },
    docker: {
      [mac]: "Install Docker Desktop: https://www.docker.com/products/docker-desktop/",
      [lin]: "Install Docker Engine: https://docs.docker.com/engine/install/  (then start the daemon)",
      [win]: "Install Docker Desktop: https://www.docker.com/products/docker-desktop/  (then launch it)",
    },
    flutter: {
      [mac]: "Install Flutter SDK: https://docs.flutter.dev/get-started/install/macos",
      [lin]: "Install Flutter SDK: https://docs.flutter.dev/get-started/install/linux",
      [win]: "Install Flutter SDK: https://docs.flutter.dev/get-started/install/windows",
    },
  };
  return hints[tool]?.[os] ?? "";
}

function detectTools() {
  const rows = [];

  // node — we are running under it.
  rows.push({ tool: "node", ok: true, detail: process.version, required: "yes" });

  // pnpm (or corepack fallback)
  let pnpmVer = capTool("pnpm", ["--version"]);
  let pnpmOk = pnpmVer.status === 0;
  if (!pnpmOk) {
    const corepack = capTool("corepack", ["--version"]);
    if (corepack.status === 0) {
      // Try to activate pnpm via corepack, then re-probe.
      runTool("corepack", ["enable"]);
      pnpmVer = capTool("pnpm", ["--version"]);
      pnpmOk = pnpmVer.status === 0;
    }
  }
  rows.push({
    tool: "pnpm",
    ok: pnpmOk,
    detail: pnpmOk ? `v${pnpmVer.stdout.trim()}` : "not found",
    required: "yes",
    hint: pnpmOk ? "" : installHint("pnpm"),
  });

  // docker CLI + daemon
  const dockerCli = capDocker(["--version"]);
  const dockerCliOk = dockerCli.status === 0;
  let daemonOk = false;
  if (dockerCliOk) {
    const info = capDocker(["info"]);
    daemonOk = info.status === 0;
  }
  rows.push({
    tool: "docker",
    ok: dockerCliOk && daemonOk,
    detail: !dockerCliOk
      ? "not found"
      : daemonOk
        ? dockerCli.stdout.trim().replace(/^Docker version\s*/i, "v")
        : "installed, daemon NOT running",
    required: "for DB",
    hint: !dockerCliOk ? installHint("docker") : daemonOk ? "" : "Start Docker Desktop / the docker daemon, then re-run.",
  });

  // flutter (optional / mobile only)
  let flutterOk = false, flutterDetail = "skipped";
  if (!SKIP_FLUTTER) {
    const f = capTool("flutter", ["--version"]);
    flutterOk = f.status === 0;
    flutterDetail = flutterOk
      ? (f.stdout.split(/\r?\n/)[0] || "installed").trim()
      : "not found";
  }
  rows.push({
    tool: "flutter",
    ok: flutterOk,
    detail: flutterDetail,
    required: "for mobile",
    hint: flutterOk || SKIP_FLUTTER ? "" : installHint("flutter"),
  });

  return { rows, pnpmOk, dockerOk: dockerCliOk && daemonOk, dockerCliOk, daemonOk, flutterOk };
}

function printPreflight(rows) {
  const pad = (s, n) => (s + " ".repeat(n)).slice(0, n);
  console.log(`  ${c.bold}${pad("tool", 10)}${pad("status", 8)}${pad("needed", 10)}detail${c.reset}`);
  for (const r of rows) {
    const mark = r.ok ? ok("✓") : (r.required === "yes" ? bad("✗") : warn("✗"));
    console.log(`  ${pad(r.tool, 10)}${mark}       ${pad(r.required, 10)}${r.detail}`);
  }
  const missing = rows.filter((r) => !r.ok && r.hint);
  if (missing.length) {
    console.log(`\n  ${c.bold}To install what's missing:${c.reset}`);
    for (const r of missing) console.log(`   • ${c.bold}${r.tool}${c.reset}: ${r.hint}`);
  }
}

// ============================================================================
// 2. ENV + KEYS
// ============================================================================
const PROVIDER_KEYS = [
  {
    key: "GEMINI_API_KEY",
    what: "Google Gemini — grounding, plan + quiz generation (the default AI brain).",
    url: "https://aistudio.google.com/apikey",
    need: "Recommended. The app needs at least ONE AI key; Gemini is the safest single choice.",
  },
  {
    key: "GROQ_API_KEY",
    what: "Groq (Qwen) — fast, low-latency downstream generation.",
    url: "https://console.groq.com/keys",
    need: "Optional. Speeds up quiz/plan generation; routing falls back to Gemini without it.",
  },
  {
    key: "DEEPGRAM_API_KEY",
    what: "Deepgram Aura — text-to-speech for the nightly audio recap.",
    url: "https://console.deepgram.com/",
    need: "Optional. Only needed for TTS/audio; everything else works without it.",
  },
  {
    key: "GOOGLE_BOOKS_API_KEY",
    what: "Google Books — richer catalog search (Open Library works without it).",
    url: "https://console.cloud.google.com/apis/credentials  (enable 'Books API', create an API key)",
    need: "Optional. Boosts catalog coverage; search still works via Open Library alone.",
  },
];

async function configureEnv() {
  // Scaffold .env from the template if absent.
  if (!existsSync(envFile)) {
    copyFileSync(envExample, envFile);
    console.log(`  Created ${warn(envFile)} from .env.example`);
  } else {
    console.log(`  Using existing ${warn(envFile)} (values you set are preserved)`);
  }

  let text = readFileSync(envFile, "utf8");
  const current = parseEnv(text);

  // Always pin DATABASE_URL to the Postgres this script manages.
  if (current.DATABASE_URL !== DATABASE_URL) {
    text = setEnvVar(text, "DATABASE_URL", DATABASE_URL);
    console.log(`  Set DATABASE_URL → ${DATABASE_URL}`);
  }

  if (!NON_INTERACTIVE) {
    console.log(
      `\n  Now the provider API keys. Paste a value, or press Enter to skip (leave blank).\n` +
        `  ${c.dim}The app runs with just one AI key — routing falls back automatically.${c.reset}`,
    );
    for (const p of PROVIDER_KEYS) {
      const existing = (current[p.key] || "").trim();
      console.log(`\n  ${c.bold}${p.key}${c.reset} — ${p.what}`);
      console.log(`    Get one: ${c.cyan}${p.url}${c.reset}`);
      console.log(`    ${c.dim}${p.need}${c.reset}`);
      if (existing) console.log(`    ${ok("(already set — press Enter to keep)")}`);
      const answer = (await ask("    value: ")).trim();
      if (answer) text = setEnvVar(text, p.key, answer);
    }
  } else {
    console.log(`  ${c.dim}Non-interactive: leaving provider keys as-is (fill them in .env later).${c.reset}`);
  }

  writeFileSync(envFile, text);
  return text;
}

// ============================================================================
// 3. ADMIN PASSWORDS
// ============================================================================
const ADMINS = [
  { env: "SEED_ADMIN_PASSWORD_RCOHEN", email: "rcohen@mytsi.org" },
  { env: "SEED_ADMIN_PASSWORD_NKUKAJ", email: "nkukaj@mytsi.org" },
  { env: "SEED_ADMIN_PASSWORD_AFARHADI", email: "afarhadi@mytsi.org" },
];

async function configureAdminPasswords(text) {
  const current = parseEnv(text);
  // Anything provided via the environment (used by the automated test / CI)
  // takes precedence and is written straight in.
  let anyFromEnv = false;
  for (const a of ADMINS) {
    const fromEnv = (process.env[a.env] || "").trim();
    if (fromEnv && fromEnv !== "changeme") {
      text = setEnvVar(text, a.env, fromEnv);
      anyFromEnv = true;
    }
  }
  if (anyFromEnv) {
    writeFileSync(envFile, text);
    console.log(`  Admin passwords taken from the environment.`);
    return text;
  }

  const needsSetting = ADMINS.some((a) => {
    const v = (current[a.env] || "").trim();
    return !v || v === "changeme";
  });

  // Nothing to do if the user already set real passwords.
  if (!needsSetting) {
    console.log(`  Admin passwords already set in .env — leaving them.`);
    return text;
  }

  let generated = null;
  if (NON_INTERACTIVE) {
    generated = true; // auto-generate so the DB seed can proceed unattended.
  } else {
    console.log(
      `  These 3 accounts are your ${c.bold}admin-panel logins${c.reset} (http://localhost:3001).`,
    );
    generated = await askYesNo("  Auto-generate 3 strong passwords and print them once?", true);
  }

  const chosen = [];
  if (generated) {
    for (const a of ADMINS) {
      const pw = strongPassword();
      text = setEnvVar(text, a.env, pw);
      chosen.push({ email: a.email, pw });
    }
    writeFileSync(envFile, text);
    console.log(`\n  ${c.bold}${c.yellow}━━ ADMIN-PANEL CREDENTIALS (shown once — save them now) ━━${c.reset}`);
    for (const ch of chosen) console.log(`    ${ch.email}   ${c.bold}${ch.pw}${c.reset}`);
    console.log(`  ${c.dim}Stored (bcrypt-hashed) in the DB on seed; the plaintext lives only in your .env.${c.reset}`);
  } else {
    for (const a of ADMINS) {
      let pw = "";
      while (!pw || pw === "changeme") {
        pw = (await ask(`    password for ${a.email}: `)).trim();
        if (pw === "changeme") console.log(`    ${bad("'changeme' is rejected — pick a real password.")}`);
      }
      text = setEnvVar(text, a.env, pw);
    }
    writeFileSync(envFile, text);
    console.log(`  Admin passwords saved to .env.`);
  }
  return text;
}

// ============================================================================
// 4. INSTALL
// ============================================================================
function installDeps(pnpmOk) {
  if (SKIP_INSTALL) {
    console.log(`  ${c.dim}--skip-install: skipping pnpm install.${c.reset}`);
    return true;
  }
  if (!pnpmOk) {
    console.log(`  ${bad("pnpm not available")} — skipping install. Enable it (${installHint("pnpm")}) and re-run.`);
    return false;
  }
  const r = runTool("pnpm", ["install"], { cwd: repoRoot });
  if (r.status !== 0) {
    console.log(`  ${bad("pnpm install failed.")} Try running 'pnpm install' manually, then re-run setup.`);
    return false;
  }
  console.log(`  ${ok("Dependencies installed.")}`);
  return true;
}

// ============================================================================
// 5. DATABASE
// ============================================================================
function containerRunning() {
  const r = capDocker(["inspect", "-f", "{{.State.Running}}", DB_CONTAINER]);
  if (r.status !== 0) return "absent";
  return r.stdout.trim() === "true" ? "running" : "stopped";
}

// Has the app schema already been applied? Used to make re-runs safe: the
// canonical migrations (create policy / create table) are NOT re-runnable, so on
// an already-migrated DB we skip them and go straight to the idempotent seeds.
function schemaAlreadyApplied() {
  const r = capDocker([
    "exec", DB_CONTAINER,
    "psql", "-U", "postgres", "-d", "postgres", "-tAc",
    "select to_regclass('public.books') is not null",
  ]);
  return r.status === 0 && r.stdout.trim() === "t";
}

async function ensureContainer() {
  const state = containerRunning();
  if (state === "running") {
    console.log(`  Container ${warn(DB_CONTAINER)} already running.`);
  } else if (state === "stopped") {
    console.log(`  Starting existing container ${warn(DB_CONTAINER)} ...`);
    const r = runDocker(["start", DB_CONTAINER]);
    if (r.status !== 0) return false;
  } else {
    console.log(`  Creating Postgres container ${warn(DB_CONTAINER)} (${DB_IMAGE}) on port ${DB_PORT} ...`);
    const r = runDocker([
      "run", "-d",
      "--name", DB_CONTAINER,
      "-e", "POSTGRES_USER=postgres",
      "-e", "POSTGRES_PASSWORD=postgres",
      "-e", "POSTGRES_DB=postgres",
      "-p", `${DB_PORT}:5432`,
      DB_IMAGE,
    ]);
    if (r.status !== 0) return false;
  }

  // Wait until Postgres accepts connections.
  process.stdout.write("  Waiting for Postgres to accept connections ");
  for (let i = 0; i < 40; i++) {
    const r = capDocker(["exec", DB_CONTAINER, "pg_isready", "-U", "postgres", "-d", "postgres"]);
    if (r.status === 0) {
      console.log(` ${ok("ready.")}`);
      return true;
    }
    process.stdout.write(".");
    await sleep(1000);
  }
  console.log(` ${bad("timed out.")}`);
  return false;
}

async function setupDatabase(text, dockerOk) {
  if (SKIP_DB) {
    console.log(`  ${c.dim}--skip-db: skipping database setup.${c.reset}`);
    return true;
  }
  if (!dockerOk) {
    console.log(
      `  ${bad("Docker isn't available/running")} — skipping DB setup.\n` +
        `  ${installHint("docker")}\n` +
        `  Once Docker is up, re-run:  ${c.bold}node scripts/setup.mjs --skip-flutter-check${c.reset}`,
    );
    return false;
  }

  const up = await ensureContainer();
  if (!up) {
    console.log(`  ${bad("Could not bring up the database container.")} Is Docker Desktop running?`);
    return false;
  }

  const env = parseEnv(text);
  const seedEnv = {
    DATABASE_URL,
    SEED_ADMIN_PASSWORD_RCOHEN: env.SEED_ADMIN_PASSWORD_RCOHEN || "",
    SEED_ADMIN_PASSWORD_NKUKAJ: env.SEED_ADMIN_PASSWORD_NKUKAJ || "",
    SEED_ADMIN_PASSWORD_AFARHADI: env.SEED_ADMIN_PASSWORD_AFARHADI || "",
  };

  // 5a. Schema: dev auth shim → canonical migrations → dev seed.
  // The canonical migrations aren't individually re-runnable, so only apply them
  // on a fresh DB. On an already-migrated DB we skip straight to the seeds.
  let r = { status: 0 };
  if (schemaAlreadyApplied()) {
    console.log(`\n  ${c.dim}Schema already present — skipping migrations (re-run safe).${c.reset}`);
  } else {
    console.log(`\n  ${c.bold}Applying schema (dev shim → migrations → dev seed)${c.reset}`);
    r = runNode(join(dbScripts, "apply-local.mjs"), { DATABASE_URL });
    if (r.status !== 0) {
      console.log(`  ${bad("Migration step failed.")}`);
      return false;
    }
  }

  // 5b. Admin accounts.
  console.log(`\n  ${c.bold}Seeding admin accounts${c.reset}`);
  r = runNode(join(dbScripts, "seed-admin-accounts.mjs"), seedEnv);
  if (r.status !== 0) {
    console.log(`  ${warn("Admin seeding skipped/failed")} (are the SEED_ADMIN_PASSWORD_* set in .env?).`);
  }

  // 5c. Demo data.
  console.log(`\n  ${c.bold}Seeding demo data${c.reset}`);
  r = runNode(join(dbScripts, "seed-demo-data.mjs"), { DATABASE_URL });
  if (r.status !== 0) {
    console.log(`  ${warn("Demo data seeding failed")} (non-fatal).`);
  }

  console.log(`\n  ${ok("Database ready")} on ${DATABASE_URL}`);
  return true;
}

// ============================================================================
// 6. FINISH
// ============================================================================
function printNextSteps({ dockerOk, flutterOk }) {
  console.log(`\n${c.bold}${c.green}✓ Setup complete.${c.reset}\n`);
  console.log(`${c.bold}Run it:${c.reset}`);
  console.log(`  API      ${c.cyan}pnpm dev:api${c.reset}      → http://localhost:8787  (GET /healthz)`);
  console.log(`  Admin    ${c.cyan}pnpm dev:admin${c.reset}    → http://localhost:3001  (log in with a seeded admin)`);
  console.log(`  Mobile   ${c.cyan}cd apps/mobile && flutter run --dart-define API_BASE_URL=http://10.0.2.2:8787${c.reset}`);
  console.log(`\n${c.bold}Admin panel:${c.reset} http://localhost:3001  — e.g. afarhadi@mytsi.org (password shown above / in .env)`);
  console.log(`${c.bold}AI Tutor API key:${c.reset} set it in the admin panel → AI Providers (not .env).`);
  if (!dockerOk) console.log(`\n${warn("Note:")} DB steps were skipped — start Docker and re-run to seed the database.`);
  if (!flutterOk && !SKIP_FLUTTER) console.log(`${warn("Note:")} Flutter wasn't found — the mobile app needs it (see docs/SETUP.md).`);
  console.log(`\nFull guide: ${c.cyan}docs/SETUP.md${c.reset}`);
}

// ============================================================================
// MAIN
// ============================================================================
async function main() {
  console.log(`${c.bold}🦉 owlnighter — developer setup${c.reset}`);
  console.log(`${c.dim}repo: ${repoRoot}${c.reset}`);
  if (NON_INTERACTIVE) console.log(`${c.dim}mode: non-interactive${c.reset}`);

  heading(1, "Preflight — checking tools");
  const tools = detectTools();
  printPreflight(tools.rows);
  if (!tools.pnpmOk) {
    console.log(`\n${warn("pnpm is required to install dependencies. Enable it and re-run:")} corepack enable`);
  }

  heading(2, "Environment & API keys");
  let text = await configureEnv();

  heading(3, "Admin-panel passwords");
  text = await configureAdminPasswords(text);

  heading(4, "Installing dependencies");
  const installed = installDeps(tools.pnpmOk);

  heading(5, "Database");
  await setupDatabase(text, tools.dockerOk && installed);

  if (rl) rl.close();
  heading(6, "Next steps");
  printNextSteps({ dockerOk: tools.dockerOk, flutterOk: tools.flutterOk });
}

main().catch((err) => {
  console.error(`\n${bad("Setup failed:")} ${err?.stack || err}`);
  if (rl) rl.close();
  process.exit(1);
});
