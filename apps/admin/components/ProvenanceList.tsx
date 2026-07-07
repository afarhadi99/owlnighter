import type { GroundingSource } from "@/lib/api";

/**
 * The operational differentiator (blueprint §"Admin dashboard feature set"):
 * every grounded fact links back to the exact sources that produced it. This
 * renders the source rows a fact cites, so AI output is inspectable, not magical.
 */
export function ProvenanceList({
  sourceIds,
  sources,
}: {
  sourceIds: string[];
  sources: GroundingSource[];
}) {
  const byId = new Map(sources.map((s) => [s.id, s]));
  const cited = sourceIds
    .map((id) => byId.get(id))
    .filter((s): s is GroundingSource => Boolean(s));

  if (cited.length === 0) {
    return (
      <span className="text-xs italic text-bad">
        no provenance — unverifiable
      </span>
    );
  }

  return (
    <ul className="space-y-1">
      {cited.map((s) => (
        <li key={s.id} className="flex items-start gap-2 text-xs">
          <span className="mt-0.5 rounded bg-ink-600 px-1 font-mono text-[10px] text-muted">
            [{s.citationIndex}]
          </span>
          <span className="flex-1">
            <span className="text-slate-300">
              {s.sourceTitle ?? s.sourceUrl ?? s.sourceType}
            </span>
            {s.sourceUrl ? (
              <>
                {" "}
                <a
                  href={s.sourceUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="text-accent hover:underline"
                >
                  ↗
                </a>
              </>
            ) : null}
            <span className="ml-1 text-muted">
              · {s.sourceType} · trust {s.trustScore.toFixed(2)}
            </span>
            {s.sourceSnippet ? (
              <span className="mt-0.5 block text-muted">“{s.sourceSnippet}”</span>
            ) : null}
          </span>
        </li>
      ))}
    </ul>
  );
}
