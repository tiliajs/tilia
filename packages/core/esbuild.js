const esbuild = require("esbuild");
const fs = require("fs");
const path = require("path");

function copyFile(sourceFile, targetFile) {
  return {
    name: "copy-dts",
    setup(build) {
      build.onEnd(() => fs.copyFileSync(sourceFile, targetFile));
    },
  };
}

const build = {
  entryPoints: ["src/index.ts"],
  bundle: true,
  sourcemap: true,
  minify: true,
  format: "esm",
  target: ["esnext"],
  ignoreAnnotations: true,
  plugins: [copyFile("./src/TiliaCore.d.ts", "./dist/index.d.ts")],
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
