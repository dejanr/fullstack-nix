import express from "express";
import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createServer as createViteServer } from "vite";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.join(__dirname, "..");

const port = Number(process.env.PORT ?? 3000);

const app = express();
const server = createServer(app);

const vite = await createViteServer({
  root,
  server: {
    middlewareMode: {
      server,
    },
    hmr: {
      server,
    },
  },
  appType: "custom",
});

app.use(vite.middlewares);
app.use(express.static(path.join(root, "public")));

app.use(async (req, res) => {
  try {
    const { render } = await vite.ssrLoadModule("/src/entry-server.tsx");
    const fullUrl = `http://localhost:${port}${req.originalUrl}`;
    const result = await render({ url: fullUrl });

    res
      .status(result.status ?? 200)
      .set({ "Content-Type": "text/html" })
      .end(result.html);
  } catch (error) {
    vite.ssrFixStacktrace(error as Error);
    console.error(error);
    res.status(500).end("SSR render failed");
  }
});

server.listen(port, () => {
  console.log(`SSR dev server running at http://localhost:${port}`);
});
