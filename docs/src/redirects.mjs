import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

const site = "https://tiliajs.dev";

const api = {
  "#tilia": "./api.html#tilia",
  "#carve": "./api.html#carve",
  "#observe": "./api.html#observe",
  "#watch": "./api.html#watch",
  "#batch": "./api.html#batch",
  "#computed": "./api.html#computed",
  "#source": "./api.html#source",
  "#store": "./api.html#store",
  "#readonly": "./api.html#readonly",
  "#signal": "./api.html#signal",
  "#derived": "./api.html#derived",
  "#lift": "./api.html#lift",
  "#leaf": "./api.html#leaf",
  "#usetilia": "./api.html#use-tilia",
  "#useTilia": "./api.html#use-tilia",
  "#usecomputed": "./api.html#use-computed",
  "#useComputed": "./api.html#use-computed",
};

const guide = {
  "#installation": "./guide.html#the-kitchen-table",
  "#goals-and-non-goals": "./guide.html#drawn-before-built",
  "#goals": "./guide.html#drawn-before-built",
  "#ddd": "./guide.html#drawn-before-built",
  "#why-tilia-helps-with-domain-driven-design": "./guide.html#drawn-before-built",
  "#the-main-idea": "./guide.html#a-living-object",
  "#fundamental-concepts": "./guide.html#a-living-object",
  "#observer-pattern": "./guide.html#a-living-object",
  "#the-observer-pattern": "./guide.html#a-living-object",
  "#dependency-graph": "./guide.html#a-living-object",
  "#how-tilia-builds-the-dependency-graph": "./guide.html#a-living-object",
  "#functional-reactive-programming": "./guide.html#values-that-follow",
  "#carving": "./guide.html#carving-a-feature",
  "#carve-and-domain-driven-design": "./guide.html#carving-a-feature",
  "#source-derived-loader": "./guide.html#letting-the-world-in",
  "#derived-loader-inside-source": "./guide.html#letting-the-world-in",
  "#patterns": "./guide.html#a-small-vocabulary",
  "#flush-batching": "./guide.html#while-alice-sleeps",
  "#flush-strategy-and-batching": "./guide.html#while-alice-sleeps",
  "#mutations-computed": "./guide.html#while-alice-sleeps",
  "#mutations-in-computed-infinite-loop-risk": "./guide.html#while-alice-sleeps",
  "#react": "./guide.html#tilia-in-react",
  "#react-integration": "./guide.html#tilia-in-react",
  "#glue-zone": "./errors.html#orphan",
  "#the-glue-zone-and-security": "./errors.html#orphan",
  "#orphan-computations-problem": "./errors.html#orphan",
  "#garbage-collection": "./guide.html#mistakes-stay-small",
  "#error-handling": "./guide.html#mistakes-stay-small",
  "#technical-reference": "./guide.html#mistakes-stay-small",
  "#deep-technical-reference": "./guide.html#mistakes-stay-small",
};

export const redirects = [
  { file: "docs.html", target: "./guide.html", hashes: { ...api, ...guide } },
  { file: "ddd.html", target: "./guide.html#drawn-before-built", hashes: {} },
  { file: "before-after.html", target: "./guide.html#carving-a-feature", hashes: {} },
  { file: "guide-fr.html", target: "./guide.html", hashes: {} },
  { file: "compare.html", target: "./guide.html#drawn-before-built", hashes: {} },
];

const guideRoutes = { ...api, ...guide };

export const guideRedirectScript = `/* Legacy guide anchors. */
(function () {
  if (location.pathname.indexOf("/query/") !== -1) return;
  var routes = ${JSON.stringify(guideRoutes)};
  var target = routes[location.hash];
  if (target) window.location.replace(target);
})();`;

function absolute(target) {
  return new URL(target.replace(/^\.\//, "/"), `${site}/`).href;
}

function document(redirect) {
  const target = absolute(redirect.target);
  const hashes = Object.fromEntries(
    Object.entries(redirect.hashes).map(([hash, value]) => [hash, absolute(value)]),
  );
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Page moved — tilia</title>
<link rel="canonical" href="${target}">
<script>
(function () {
  var routes = ${JSON.stringify(hashes)};
  var target = routes[window.location.hash] || ${JSON.stringify(target)};
  var next = new URL(target);
  next.search = window.location.search;
  window.location.replace(next.href);
})();
</script>
<meta http-equiv="refresh" content="0;url=${target}">
</head>
<body>
<main>
  <h1>Page moved</h1>
  <p>This documentation now lives at <a href="${target}">${target}</a>.</p>
</main>
</body>
</html>
`;
}

export async function renderRedirects(dir) {
  await mkdir(dir, { recursive: true });
  await Promise.all(
    redirects.map((redirect) => writeFile(path.join(dir, redirect.file), document(redirect))),
  );
}
