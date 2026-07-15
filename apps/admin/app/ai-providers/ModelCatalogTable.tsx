"use client";
import { useState, useTransition } from "react";
import { fetchModelsAction } from "./actions";
import type { AiModelInfo } from "@/lib/api";

type SortKey = "id" | "contextLength";

export function ModelCatalogTable({ provider }: { provider: "groq" | "openrouter" }) {
  const [models, setModels] = useState<AiModelInfo[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [sortKey, setSortKey] = useState<SortKey>("id");
  const [sortDir, setSortDir] = useState<1 | -1>(1);
  const [modalityFilter, setModalityFilter] = useState("");
  const [pending, startTransition] = useTransition();

  function load() {
    setError(null);
    startTransition(async () => {
      const result = await fetchModelsAction(provider);
      if (result.error) setError(result.error);
      else setModels(result.models ?? []);
    });
  }

  function sortBy(key: SortKey) {
    if (key === sortKey) setSortDir((d) => (d === 1 ? -1 : 1) as 1 | -1);
    else {
      setSortKey(key);
      setSortDir(1);
    }
  }

  const filtered = (models ?? []).filter(
    (m) => !modalityFilter || (m.modality ?? "").toLowerCase().includes(modalityFilter.toLowerCase()),
  );
  const sorted = [...filtered].sort((a, b) => {
    if (sortKey === "contextLength") return ((a.contextLength ?? 0) - (b.contextLength ?? 0)) * sortDir;
    return a.id.localeCompare(b.id) * sortDir;
  });

  return (
    <div className="mt-3">
      <div className="mb-2 flex items-center gap-2">
        <button
          type="button"
          onClick={load}
          disabled={pending}
          className="rounded border border-accent/40 bg-accent/10 px-2 py-1 text-xs text-accent disabled:opacity-50"
        >
          {pending ? "Fetching..." : "Fetch models"}
        </button>
        {models ? (
          <input
            value={modalityFilter}
            onChange={(e) => setModalityFilter(e.target.value)}
            placeholder="filter by modality (e.g. text)"
            className="rounded border border-line bg-ink-700 px-2 py-1 text-xs text-slate-100"
          />
        ) : null}
        {error ? <span className="text-xs text-bad">{error}</span> : null}
      </div>
      {models ? (
        <div className="overflow-x-auto rounded-md border border-line">
          <table className="w-full min-w-[560px] border-collapse text-xs">
            <thead className="bg-ink-700 text-muted">
              <tr>
                <th className="cursor-pointer px-2 py-1 text-left" onClick={() => sortBy("id")}>
                  Model {sortKey === "id" ? (sortDir === 1 ? "▲" : "▼") : ""}
                </th>
                <th className="cursor-pointer px-2 py-1 text-left" onClick={() => sortBy("contextLength")}>
                  Context {sortKey === "contextLength" ? (sortDir === 1 ? "▲" : "▼") : ""}
                </th>
                <th className="px-2 py-1 text-left">Pricing (prompt/completion)</th>
              </tr>
            </thead>
            <tbody>
              {sorted.map((m) => (
                <tr key={m.id} className="border-t border-line bg-ink-800 hover:bg-ink-700">
                  <td className="px-2 py-1 font-mono">{m.id}</td>
                  <td className="px-2 py-1">{m.contextLength ?? "—"}</td>
                  <td className="px-2 py-1">
                    {m.pricing ? `${m.pricing.prompt ?? "—"} / ${m.pricing.completion ?? "—"}` : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {sorted.length === 0 ? (
            <div className="p-3 text-center text-xs text-muted">No models match the filter.</div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
