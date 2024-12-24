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

const build = {
  entryPoints: ["src/index.js"],
  bundle: true,
  sourcemap: true,
  minify: process.env.CANARY ? false : true,
  target: ["esnext"],
  ignoreAnnotations: true,
  plugins: [
    nodeExternalsPlugin(),
    copyFile("./src/index.d.ts", "./dist/index.d.ts"),
  ],
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
