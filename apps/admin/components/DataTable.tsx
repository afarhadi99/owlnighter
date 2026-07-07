import type { ReactNode } from "react";

export interface Column<Row> {
  key: string;
  header: string;
  /** Cell renderer. Defaults to String(row[key]). */
  render?: (row: Row) => ReactNode;
  className?: string;
}

export function DataTable<Row extends Record<string, unknown>>({
  columns,
  rows,
  empty = "No rows.",
  rowKey,
}: {
  columns: Column<Row>[];
  rows: Row[];
  empty?: ReactNode;
  rowKey: (row: Row, index: number) => string;
}) {
  if (rows.length === 0) {
    return (
      <div className="rounded-md border border-line bg-ink-800 p-6 text-center text-sm text-muted">
        {empty}
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-md border border-line">
      <table className="data w-full min-w-[640px] border-collapse">
        <thead className="bg-ink-700 text-muted">
          <tr>
            {columns.map((c) => (
              <th
                key={c.key}
                className="whitespace-nowrap px-3 py-2 text-[11px] uppercase tracking-wider"
              >
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr
              key={rowKey(row, i)}
              className="border-t border-line bg-ink-800 hover:bg-ink-700"
            >
              {columns.map((c) => (
                <td
                  key={c.key}
                  className={`px-3 py-2 align-top ${c.className ?? ""}`}
                >
                  {c.render ? c.render(row) : String(row[c.key] ?? "")}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
