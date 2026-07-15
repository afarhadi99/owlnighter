import { z } from "zod";
import { ApiError } from "./common.js";
import { ENDPOINTS, type EndpointDef } from "./endpoints.js";

/** Convert `/v1/plans/:id` → `/v1/plans/{id}` and collect param names. */
function toOpenApiPath(path: string): { path: string; params: string[] } {
  const params: string[] = [];
  const converted = path.replace(/:([A-Za-z0-9_]+)/g, (_m, name: string) => {
    params.push(name);
    return `{${name}}`;
  });
  return { path: converted, params };
}

function jsonSchema(schema: z.ZodType, io: "input" | "output"): Record<string, unknown> {
  const out = z.toJSONSchema(schema, {
    target: "draft-2020-12",
    io,
    unrepresentable: "any",
  }) as Record<string, unknown>;
  delete out["$schema"];
  return out;
}

const errorResponse = {
  description: "Error",
  content: { "application/json": { schema: jsonSchema(ApiError, "output") } },
};

function operationFor(ep: EndpointDef, params: string[]) {
  const op: Record<string, unknown> = {
    operationId: ep.operationId,
    summary: ep.summary,
    tags: [ep.tag],
  };

  if (ep.auth === "admin_panel") op["security"] = [{ adminBearerAuth: [] }];
  else if (ep.auth !== "none") op["security"] = [{ bearerAuth: [] }];

  if (params.length > 0) {
    op["parameters"] = params.map((name) => ({
      name,
      in: "path",
      required: true,
      schema: { type: "string", format: "uuid" },
    }));
  }

  if (ep.request) {
    op["requestBody"] = {
      required: true,
      content: { "application/json": { schema: jsonSchema(ep.request, "input") } },
    };
  }

  const responses: Record<string, unknown> = {
    "400": errorResponse,
    "401": errorResponse,
    "500": errorResponse,
  };
  responses[ep.response ? "200" : "204"] = ep.response
    ? {
        description: "OK",
        content: { "application/json": { schema: jsonSchema(ep.response, "output") } },
      }
    : { description: "No Content" };
  op["responses"] = responses;

  return op;
}

/** Build the full OpenAPI 3.1 document from the endpoint registry. */
export function buildOpenApiDocument(version = "0.1.0"): Record<string, unknown> {
  const paths: Record<string, Record<string, unknown>> = {};

  for (const ep of ENDPOINTS) {
    const { path, params } = toOpenApiPath(ep.path);
    paths[path] ??= {};
    paths[path][ep.method] = operationFor(ep, params);
  }

  return {
    openapi: "3.1.0",
    info: {
      title: "owlnighter API",
      version,
      description:
        "Authoritative API for the owlnighter reading-habit platform. Generated from Zod contracts.",
      license: { name: "MIT" },
    },
    servers: [{ url: "http://localhost:8787" }, { url: "https://api.owlnighter.app" }],
    components: {
      securitySchemes: {
        bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" },
        adminBearerAuth: { type: "http", scheme: "bearer", bearerFormat: "opaque admin session token" },
      },
    },
    paths,
  };
}
