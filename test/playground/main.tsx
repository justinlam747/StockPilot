import "../../frontend/src/styles/globals.css";
import { createRoot } from "react-dom/client";
import Playground from "./Playground";

const root = document.getElementById("playground");
if (root) {
  createRoot(root).render(<Playground />);
}
