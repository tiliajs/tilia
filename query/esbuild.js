import esbuild from "esbuild";
import { nodeExternalsPlugin } from "esbuild-node-externals";
import { copyFileSync } from "fs";

function copyFile(sourceFile, targetFile) {
  return {
    name: "copy-dts",
    setup(build) {
      build.onEnd(() => copyFileSync(sourceFile, targetFile));
    },
  };
}

// The app imports the root "tilia"; the same import here keeps both
// packages on one tilia instance (one module-level context).
function tiliaRoot() {
  return {
    name: "tilia-root",
    setup(build) {
      build.onResolve({ filter: /^tilia\/src\/Tilia\.mjs$/ }, () => ({
        path: "tilia",
        external: true,
      }));
    },
  };
}

const shared = {
  bundle: true,
  sourcemap: true,
  minify: process.env.CANARY ? false : true,
  target: ["esnext"],
  ignoreAnnotations: true,
};

// One bundle per entry point. `@tilia/query/indexeddb` is its own so that an
// application that persists in memory never downloads a line of IndexedDB.
const entries = [
  {
    entry: "src/index.js",
    out: "dist/index",
    types: "./src/index.d.ts",
    plugins: [tiliaRoot(), nodeExternalsPlugin()],
  },
  {
    entry: "src/indexeddb.js",
    out: "dist/indexeddb",
    types: "./src/indexeddb.d.ts",
    plugins: [nodeExternalsPlugin()],
  },
];

Promise.all(
  entries.flatMap(({ entry, out, types, plugins }) => {
    const build = {
      ...shared,
      entryPoints: [entry],
      plugins: [...plugins, copyFile(types, `${out}.d.ts`)],
    };
    return [
      esbuild.build({ ...build, format: "cjs", outfile: `${out}.cjs` }),
      esbuild.build({ ...build, format: "esm", outfile: `${out}.mjs` }),
    ];
  })
).catch((e) => {
  console.log(e);
  process.exit(1);
});
