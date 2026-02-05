import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// In Lambda, the structure is /var/task/server/ and /var/task/client/
const serverEntryPath = path.join(__dirname, "entry-server.js");
const manifestPath = path.join(__dirname, "..", "client", ".vite", "manifest.json");

type Manifest = Record<string, { file: string; css?: string[] }>;

let cachedAssets: { js: string; css: string } | null = null;

const getAssets = async () => {
  if (cachedAssets) return cachedAssets;

  try {
    const manifestContent = await readFile(manifestPath, "utf-8");
    const manifest: Manifest = JSON.parse(manifestContent);
    const entry = manifest["src/entry-client.tsx"];
    const styleEntry = manifest["style.css"];

    cachedAssets = {
      js: `/${entry.file}`,
      css: styleEntry
        ? `/${styleEntry.file}`
        : entry.css?.[0]
          ? `/${entry.css[0]}`
          : "/assets/styles.css",
    };
  } catch {
    cachedAssets = {
      js: "/assets/entry-client.js",
      css: "/assets/styles.css",
    };
  }

  return cachedAssets;
};

type LambdaEvent = {
  rawPath?: string;
  path?: string;
  headers?: Record<string, string | undefined>;
};

export const handler = async (event?: LambdaEvent) => {
  try {
    const { render } = await import(serverEntryPath);
    const requestPath = event?.rawPath ?? event?.path ?? "/";
    const host = event?.headers?.host ?? event?.headers?.Host ?? "localhost";
    const protocol = "https";
    const fullUrl = `${protocol}://${host}${requestPath}`;

    const assets = await getAssets();
    const result = await render({ url: fullUrl, assets });

    return {
      statusCode: result.status ?? 200,
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "public, max-age=0, s-maxage=300, stale-while-revalidate=60",
      },
      body: result.html,
    };
  } catch (error) {
    console.error("SSR render failed", error);
    return {
      statusCode: 500,
      headers: { "content-type": "text/plain; charset=utf-8" },
      body: "SSR render failed",
    };
  }
};
