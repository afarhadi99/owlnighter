import { api, ApiRequestError } from "@/lib/api";
import type { AdminGroundingResponse } from "@/lib/api";
import { PageHeader } from "@/components/PageHeader";
import { Badge, confidenceTone } from "@/components/Badge";
import { ProvenanceList } from "@/components/ProvenanceList";
import { OverrideForm } from "./OverrideForm";

const bucketTone = {
  auto_accepted: "good",
  needs_review: "warn",
  limited: "bad",
} as const;

const statusTone = {
  grounded: "good",
  partial: "warn",
  pending: "neutral",
  blocked: "bad",
} as const;

export default async function GroundingDetailPage({
  params,
}: {
  // Next 15: params is a Promise in async server components.
  params: Promise<{ bookId: string }>;
}) {
  const { bookId } = await params;

  let data: AdminGroundingResponse | null = null;
  let error: string | null = null;
  try {
    data = await api.getGrounding(bookId);
  } catch (err) {
    error =
      err instanceof ApiRequestError
        ? `${err.status}: ${err.body?.error.message ?? err.message}`
        : (err as Error).message;
  }

  return (
    <div>
      <PageHeader
        title="Grounding Detail"
        subtitle={
          <>
            Book <span className="font-mono text-slate-300">{bookId}</span> — every
            fact links to the exact sources that produced it.
          </>
        }
        right={
          data ? (
            <div className="flex gap-2">
              <Badge tone={statusTone[data.groundingStatus]}>
                {data.groundingStatus}
              </Badge>
              <Badge tone={bucketTone[data.reviewBucket]}>
                {data.reviewBucket}
              </Badge>
            </div>
          ) : null
        }
      />

      {error ? (
        <div className="rounded-md border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">
          GET /v1/admin/books/{bookId}/grounding failed — {error}
          <div className="mt-1 text-xs text-muted">
            Confirm the API is running at{" "}
            {process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8787"} and the
            book exists.
          </div>
        </div>
      ) : null}

      {data ? (
        <div className="space-y-6">
          {/* Runs */}
          <Section title={`Grounding runs (${data.runs.length})`}>
            <div className="space-y-1">
              {data.runs.map((r) => (
                <div
                  key={r.id}
                  className="flex flex-wrap items-center gap-2 rounded border border-line bg-ink-800 px-3 py-2 text-xs"
                >
                  <Badge tone="info">{r.runKind}</Badge>
                  <Badge
                    tone={
                      r.status === "succeeded"
                        ? "good"
                        : r.status === "failed"
                          ? "bad"
                          : "warn"
                    }
                  >
                    {r.status}
                  </Badge>
                  <span className="font-mono text-muted">
                    {r.provider}/{r.providerModel}
                  </span>
                  <span className="text-muted">{r.createdAt}</span>
                </div>
              ))}
              {data.runs.length === 0 ? (
                <p className="text-sm text-muted">No runs recorded.</p>
              ) : null}
            </div>
          </Section>

          {/* Facts with provenance */}
          <Section title={`Extracted facts (${data.facts.length})`}>
            <div className="space-y-3">
              {data.facts.map((f) => (
                <div
                  key={f.id}
                  className="rounded-md border border-line bg-ink-800 p-3"
                >
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge tone="neutral">{f.factType}</Badge>
                    <span className="font-mono text-sm text-slate-100">
                      {f.key}
                    </span>
                    <span className="font-mono text-sm text-accent">
                      {JSON.stringify(f.value)}
                    </span>
                    <span className="ml-auto text-xs text-muted">
                      confidence{" "}
                      <Badge tone={confidenceTone(f.confidence)}>
                        {f.confidence.toFixed(2)}
                      </Badge>
                    </span>
                  </div>
                  <div className="mt-2 border-t border-line pt-2">
                    <div className="mb-1 text-[11px] uppercase tracking-widest text-muted">
                      Provenance
                    </div>
                    <ProvenanceList
                      sourceIds={f.provenanceSourceIds}
                      sources={data!.sources}
                    />
                  </div>
                </div>
              ))}
              {data.facts.length === 0 ? (
                <p className="text-sm text-muted">No facts extracted.</p>
              ) : null}
            </div>
          </Section>

          {/* Citations / sources */}
          <Section title={`Sources & citations (${data.sources.length})`}>
            <div className="space-y-1">
              {data.sources.map((s) => (
                <div
                  key={s.id}
                  className="flex flex-wrap items-center gap-2 rounded border border-line bg-ink-800 px-3 py-2 text-xs"
                >
                  <span className="rounded bg-ink-600 px-1 font-mono text-[10px] text-muted">
                    [{s.citationIndex}]
                  </span>
                  <Badge tone="neutral">{s.sourceType}</Badge>
                  <span className="text-slate-300">
                    {s.sourceTitle ?? s.sourceUrl ?? "—"}
                  </span>
                  {s.sourceUrl ? (
                    <a
                      href={s.sourceUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="text-accent hover:underline"
                    >
                      ↗
                    </a>
                  ) : null}
                  <span className="ml-auto text-muted">
                    trust{" "}
                    <Badge tone={confidenceTone(s.trustScore)}>
                      {s.trustScore.toFixed(2)}
                    </Badge>
                  </span>
                </div>
              ))}
              {data.sources.length === 0 ? (
                <p className="text-sm text-muted">No sources.</p>
              ) : null}
            </div>
          </Section>

          {/* Manual override */}
          <Section title="Manual override / trust lock">
            <div className="rounded-md border border-line bg-ink-800 p-4">
              <OverrideForm bookId={bookId} />
            </div>
          </Section>
        </div>
      ) : null}
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section>
      <h2 className="mb-2 font-mono text-sm font-semibold text-slate-200">
        {title}
      </h2>
      {children}
    </section>
  );
}
