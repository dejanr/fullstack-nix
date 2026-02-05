import { renderToString } from "react-dom/server";
import { App } from "./App";

type RenderOptions = {
  url: string;
  assets?: {
    js: string;
    css: string;
  };
};

export const render = ({ assets }: RenderOptions) => {
  const appHtml = renderToString(<App />);

  const js = assets?.js ?? "/src/entry-client.tsx";
  const css = assets?.css ?? "/src/styles/globals.css";

  const html = `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Hello World</title>
    <link rel="icon" href="/favicon.ico" />
    <link rel="stylesheet" href="${css}" />
  </head>
  <body>
    <div id="app">${appHtml}</div>
    <script type="module" src="${js}"></script>
  </body>
</html>`;

  return { html, status: 200 };
};
