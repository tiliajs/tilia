import MarkdownIt from "markdown-it";
import container from "markdown-it-container";
import Prism from "prismjs";
import "prismjs/components/prism-typescript.js";
import "prismjs/components/prism-rescript.js";
import "prismjs/components/prism-gherkin.js";
import "prismjs/components/prism-yaml.js";

const languages = ["typescript", "rescript", "res", "gherkin", "yaml"];
const toggle =
  '<button class="lang-toggle" type="button" aria-label="Switch example language"><span class="lt lt-ts">TS</span><span class="lt lt-res">RES</span></button>';

function language(name) {
  return name === "res" ? "rescript" : name;
}

function highlight(code, name, signature = false) {
  const prismName = language(name);
  const grammar = Prism.languages[prismName];
  if (!grammar) throw new Error(`Unsupported Prism language "${prismName}"`);
  const html = Prism.highlight(code, grammar, prismName);
  const classes = signature ? `sig language-${name}` : `language-${name}`;
  return `<pre class="${classes}"><code>${html}</code></pre>`;
}

function callouts(body) {
  for (const match of body.matchAll(/^:{3,}[ \t]*(\S*)$/gm)) {
    const name = match[1];
    if (name && name !== "story" && name !== "pro" && name !== "def") {
      throw new Error(`unknown callout container ":::${name}" (expected "story", "pro" or "def")`);
    }
  }
}

function pairs(tokens) {
  for (let index = 0; index < tokens.length; index++) {
    const token = tokens[index];
    if (token?.type !== "fence") continue;
    const name = language(token.info.trim());
    const next = tokens[index + 1];
    if (name === "typescript" && next?.type === "fence" && language(next.info.trim()) === "rescript") {
      token.meta = { pair: "start" };
      next.meta = { pair: "end" };
      index++;
    }
  }
}

function headings(tokens) {
  if (tokens.some((token) => token.type === "heading_open")) {
    throw new Error("API entry body must not contain headings");
  }
}

function markdown(page) {
  const md = new MarkdownIt({ html: false });
  md.use(container, "story", {
    render: (tokens, index) =>
      tokens[index]?.nesting === 1 ? '<div class="story">\n<span class="k">Story</span>\n' : "</div>\n",
  });
  md.use(container, "pro", {
    render: (tokens, index) =>
      tokens[index]?.nesting === 1 ? '<div class="pro">\n<span class="k">Pro tip</span>\n' : "</div>\n",
  });
  md.use(container, "def", {
    render: (tokens, index) => (tokens[index]?.nesting === 1 ? '<div class="defcard">\n' : "</div>\n"),
  });

  md.renderer.rules.fence = (tokens, index) => {
    const token = tokens[index];
    if (!token) return "";
    const name = language(token.info.trim());
    if (!languages.includes(name)) {
      throw new Error(
        `code fence uses unsupported language "${name}" (only "typescript", "rescript", "res", "gherkin", or "yaml" allowed)`,
      );
    }
    const code = highlight(token.content.replace(/\n$/, ""), name);
    const pair = token.meta?.pair;
    const label = name === "gherkin" ? "Contract" : "Example";
    const open =
      pair === "start"
        ? `<figure class="${page === "api" ? "ex" : "example"}" data-pair><figcaption class="exbar"><span class="k">Example</span>${page === "guide" ? toggle : ""}</figcaption>`
        : pair
          ? ""
          : `<figure class="${page === "api" ? "ex" : "example"}"><figcaption class="exbar"><span class="k">${label}</span></figcaption>`;
    return `${open}${code}${pair === "start" ? "" : "</figure>"}`;
  };

  const paragraph = md.renderer.rules.paragraph_open;
  md.renderer.rules.paragraph_open = (tokens, index, options, env, self) => {
    const token = tokens[index];
    if (page === "guide" && token?.level === 0) {
      const current = token.attrGet("class");
      token.attrSet("class", current ? `${current} body` : "body");
    }
    return paragraph ? paragraph(tokens, index, options, env, self) : self.renderToken(tokens, index, options);
  };
  return md;
}

const api = markdown("api");
const guide = markdown("guide");

function render(md, text, page) {
  callouts(text);
  const tokens = md.parse(text, {});
  if (page === "api") headings(tokens);
  pairs(tokens);
  return md.renderer.render(tokens, md.options, {});
}

export function apiMd(text) {
  return render(api, text, "api");
}

export function guideMd(text) {
  return render(guide, text, "guide");
}

export function typescript(text) {
  return highlight(text, "typescript", true);
}

export function rescript(text) {
  return highlight(text, "rescript", true);
}
