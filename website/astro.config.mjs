// @ts-check
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import { visit } from "unist-util-visit";

// https://astro.build/config
export default defineConfig({
  build: {
    format: "preserve",
  },
  markdown: {
    syntaxHighlight: "prism",
    remarkPlugins: [myRemarkPlugin],
  },
  vite: {
    plugins: [tailwindcss()],
  },
  redirects: {
    "/ddd": "/docs#ddd",
  },
});

const styleRegex = /^(.*) \{\.(.*)\}$/s;

// Add custom class name to headings and paragraphs
/** @type {import('unified').Plugin<[], import('mdast').Root>} */
function myRemarkPlugin() {
  return (tree) => {
    visit(tree, (node) => {
      if (node.type === "heading") {
        const child = node.children[node.children.length - 1];
        if (child && child.type === "text") {
          const re = styleRegex.exec(child.value);
          if (re) {
            const [, text, style] = re;
            child.value = text;
            const data = node.data || (node.data = {});
            data.hName = `h${node.depth}`;
            data.hProperties = { class: style };
          }
        }
      } else if (node.type === "paragraph") {
        const child = node.children[node.children.length - 1];
        if (child && child.type === "text") {
          const re = styleRegex.exec(child.value);
          if (re) {
            const [, text, style] = re;
            child.value = text;
            const data = node.data || (node.data = {});
            data.hName = "p";
            data.hProperties = { class: style };
          }
        }
      }
    });
  };
}
