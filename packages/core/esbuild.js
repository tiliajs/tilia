const esbuild = require("esbuild");

const build = {
  entryPoints: ["src/index.ts"],
  bundle: true,
  sourcemap: true,
  minify: true,
  format: "esm",
  target: ["esnext"],
  ignoreAnnotations: true,
};

Promise.all([
  // CJS build
  esbuild.build({
    ...build,
    format: "cjs",
    outfile: "dist/index.cjs.js",
  }),
  // ESM build
  esbuild.build({
    ...build,
    format: "esm",
    outfile: "dist/index.esm.js",
  }),
]).catch((e) => {
  console.log(e);
  process.exit(1);
});
