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

const build = {
  entryPoints: ["src/index.js"],
  bundle: true,
  sourcemap: true,
  minify: process.env.CANARY ? false : true,
  target: ["esnext"],
  ignoreAnnotations: true,
  plugins: [
    tiliaRoot(),
    nodeExternalsPlugin(),
    copyFile("./src/index.d.ts", "./dist/index.d.ts"),
  ],
};

Promise.all([
  esbuild.build({
    ...build,
    format: "cjs",
    outfile: "dist/index.cjs",
  }),
  esbuild.build({
    ...build,
    format: "esm",
    outfile: "dist/index.mjs",
  }),
]).catch((e) => {
  console.log(e);
  process.exit(1);
});
