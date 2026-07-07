import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { buildOpenApiDocument } from "../src/openapi.js";

const here = dirname(fileURLToPath(import.meta.url));
const outPath = resolve(here, "../openapi.json");

const doc = buildOpenApiDocument();
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(doc, null, 2) + "\n", "utf8");

const pathCount = Object.keys((doc as { paths: object }).paths).length;
console.log(`✓ Wrote OpenAPI 3.1 doc with ${pathCount} paths → ${outPath}`);
