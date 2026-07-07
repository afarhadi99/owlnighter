# infra/

Deployment and local-stack tooling for owlnighter.

```
infra/
  sql/                     # schema (0001) + RLS (0002) — do not edit here
  docker/
    Dockerfile.api         # multi-stage image for apps/api
    docker-compose.yml     # local Postgres(pgvector) + API
  cloud-run/
    api-service.yaml       # Knative manifest for the API (scale-to-zero)
  firebase/
    README.md              # FCM/APNs setup + server push payload shapes
  codemagic.sample.yaml    # sample Flutter mobile release pipeline
```

## Deployment pattern

The blueprint's recommended default is **Supabase + Cloud Run + Vercel +
Codemagic**, chosen to keep each layer at the cheapest option that still does
its job well:

| Component | Host | Why (cost-aware rationale) |
| --- | --- | --- |
| Database / Auth / Storage | **Supabase** | One managed platform gives a real Postgres instance plus Auth, Storage, Realtime, backups, and pgvector — no need to run/pay for several services. Pricing is org-based plus per-project compute. |
| API / workers | **Cloud Run** | Container-friendly and **scales to zero**, so a bursty, mostly-nightly workload costs nothing while idle; requests/CPU/RAM have a free tier. See `cloud-run/api-service.yaml`. |
| Admin web (Next.js) | **Vercel** | Fastest path to ship the App Router admin; usage-based pricing with a free Hobby tier. |
| Flutter mobile CI/CD | **Codemagic** | Purpose-built Flutter release automation (build, sign, submit) with a free tier; sample at `codemagic.sample.yaml`. GitHub Actions + fastlane is the alternative. |
| Push | **FCM / APNs** | Cross-platform push for Flutter; iOS via APNs configured inside Firebase. See `firebase/README.md`. |

Why this shape: the phone stays thin, the API stays authoritative (all provider
keys and push-send rights are backend-only), and the AI/job layer is
container-portable so you can move off Cloud Run without app-store releases.

### Alternatives

- **Local DB:** `docker/docker-compose.yml` (raw pgvector Postgres) is the
  minimal loop. For Auth/Storage/RLS work, prefer **Supabase local**
  (`supabase start`), which the app's `.env` URLs already target.
- **API host:** Cloud Run → Fly.io / Render / any container host.
- **Admin:** Vercel → Cloud Run.

## Local development

Minimal DB + API loop (from repo root):

```bash
cp .env.example .env    # fill in keys
docker compose -f infra/docker/docker-compose.yml up --build
# API on http://localhost:8787, Postgres on 127.0.0.1:54322
```

Full Supabase experience (Auth/Storage/Studio) instead:

```bash
supabase start          # boots Postgres + Auth + Storage on :54321/:54322
```

The two are mutually exclusive on ports — pick one per `.env`.

## Cloud Run deploy (sketch)

```bash
# 1. Build & push the image (from repo root — needs the whole workspace).
docker build -f infra/docker/Dockerfile.api -t gcr.io/PROJECT_ID/owlnighter-api:latest .
docker push gcr.io/PROJECT_ID/owlnighter-api:latest

# 2. Create secrets in Secret Manager (once) — names must match api-service.yaml.
for s in DATABASE_URL SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY SUPABASE_ANON_KEY \
         GEMINI_API_KEY GROQ_API_KEY DEEPGRAM_API_KEY GOOGLE_BOOKS_API_KEY \
         FCM_SERVICE_ACCOUNT_JSON FCM_PROJECT_ID; do
  printf '%s' "${!s}" | gcloud secrets create "$s" --data-file=- 2>/dev/null || \
  printf '%s' "${!s}" | gcloud secrets versions add "$s" --data-file=-
done

# 3. Deploy the service.
gcloud run services replace infra/cloud-run/api-service.yaml --region=us-central1
```

Fill the `PROJECT_ID` / `SERVICE_ACCOUNT` placeholders in
`cloud-run/api-service.yaml` first, and grant the runtime service account
`roles/secretmanager.secretAccessor`.

## Firebase / push

See [`firebase/README.md`](firebase/README.md) for FCM project setup, the APNs
auth-key upload, config-file placement, and the four server-send payload shapes
(nightly reminder, streak warning, completion celebration, re-engagement).

## Mobile release

See [`codemagic.sample.yaml`](codemagic.sample.yaml) for a sample Flutter
release pipeline (analyze, test, build Android + iOS). Copy it to a
`codemagic.yaml` at the repo root when you wire up a real Codemagic app.
