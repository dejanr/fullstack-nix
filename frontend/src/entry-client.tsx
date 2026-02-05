import { hydrateRoot } from "react-dom/client";
import { App } from "./App";
import "./styles/globals.css";

hydrateRoot(document.getElementById("app")!, <App />);
