import esbuild from "esbuild";
import {copyFileSync} from "fs";

function copyFile(sourceFile, targetFile) {
  return {
    name: "copy-file",
    setup(build) {
      build.onEnd(() => copyFileSync(sourceFile, targetFile));
    },
  };
}

const build = {
  entryPoints: ["src/index.js"],
  bundle: true,
  sourcemap: true,
  minify: false,
  target: ["esnext"],
  ignoreAnnotations: true,
  packages: "external",
  plugins: [
    copyFile("./src/index.d.ts", "./dist/index.d.ts"),
    copyFile("../website/public/llms.txt", "./llms.txt"),
    copyFile("../website/public/llms-rescript.md", "./llms-rescript.md"),
    copyFile("../website/public/llms-typescript.md", "./llms-typescript.md"),
  ],
};

Promise.all([
  // CJS build
  esbuild.build({
    ...build,
    format: "cjs",
    outfile: "dist/index.cjs",
  }),
  // ESM build
  esbuild.build({
    ...build,
    format: "esm",
    outfile: "dist/index.mjs",
  }),
]).catch((e) => {
  console.log(e);
  process.exit(1);
});
