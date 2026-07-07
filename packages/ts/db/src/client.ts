import { drizzle, type PostgresJsDatabase } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema.js";

export type Db = PostgresJsDatabase<typeof schema>;

let client: ReturnType<typeof postgres> | undefined;
let db: Db | undefined;

/**
 * Lazily create a singleton Drizzle client. Uses the service-role DATABASE_URL —
 * backend only. Never import this from client apps.
 */
export function getDb(databaseUrl: string): Db {
  if (db) return db;
  client = postgres(databaseUrl, { max: 10, prepare: false });
  db = drizzle(client, { schema });
  return db;
}

export async function closeDb(): Promise<void> {
  await client?.end({ timeout: 5 });
  client = undefined;
  db = undefined;
}

export { schema };
