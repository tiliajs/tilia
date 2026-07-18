import { execFile as execFileCb } from "node:child_process";
import { promisify } from "node:util";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const execFile = promisify(execFileCb);

const STABLE = /^\d+\.\d+\.\d+$/;
const AUDITS = [
  {
    id: "tilia-lineage",
    label: "tilia (with @tilia/core lineage)",
    sources: [
      { name: "@tilia/core", resiPaths: ["package/src/TiliaCore.resi"] },
      { name: "tilia", resiPaths: ["package/src/Tilia.resi"] },
    ],
  },
  {
    id: "tilia-react",
    label: "@tilia/react",
    sources: [
      {
        name: "@tilia/react",
        // Old versions used src/Tilia.resi, newer use src/TiliaReact.resi.
        resiPaths: ["package/src/TiliaReact.resi", "package/src/Tilia.resi"],
      },
    ],
  },
];

function parseSemver(version) {
  const [major, minor, patch] = version.split(".").map(Number);
  return { major, minor, patch };
}

function compareSemver(a, b) {
  const av = parseSemver(a);
  const bv = parseSemver(b);
  if (av.major !== bv.major) return av.major - bv.major;
  if (av.minor !== bv.minor) return av.minor - bv.minor;
  return av.patch - bv.patch;
}

function minorKey(version) {
  const { major, minor } = parseSemver(version);
  return `${major}.${minor}`;
}

function compareRelease(a, b, sourceOrder) {
  const ai = sourceOrder.get(a.source) ?? Number.MAX_SAFE_INTEGER;
  const bi = sourceOrder.get(b.source) ?? Number.MAX_SAFE_INTEGER;
  if (ai !== bi) return ai - bi;
  return compareSemver(a.version, b.version);
}

function collectMinorSnapshots(releases, sourceOrder) {
  const latestByMinor = new Map();
  for (const release of releases) {
    const key = `${release.source}@${minorKey(release.version)}`;
    const prev = latestByMinor.get(key);
    if (!prev || compareSemver(release.version, prev.version) > 0) {
      latestByMinor.set(key, release);
    }
  }
  return [...latestByMinor.values()].sort((a, b) => compareRelease(a, b, sourceOrder));
}

function stripComments(code) {
  const noBlock = code.replace(/\/\*[\s\S]*?\*\//g, "");
  return noBlock
    .split("\n")
    .map((line) => line.replace(/\/\/.*$/, ""))
    .join("\n");
}

function parseExports(resi) {
  const code = stripComments(resi);
  const symbols = new Set();

  const typeRe = /^\s*type\s+(?:rec\s+)?([A-Za-z_][A-Za-z0-9_']*)\b/gm;
  const letRe = /^\s*let\s+([A-Za-z_][A-Za-z0-9_']*)\s*:/gm;

  for (const [, name] of code.matchAll(typeRe)) {
    symbols.add(`type:${name}`);
  }
  for (const [, name] of code.matchAll(letRe)) {
    symbols.add(`let:${name}`);
  }

  return symbols;
}

async function npmJson(args, cwd) {
  const { stdout } = await execFile("npm", args, {
    cwd,
    maxBuffer: 64 * 1024 * 1024,
  });
  return JSON.parse(stdout);
}

async function getStableVersions(pkg, cwd) {
  const versions = await npmJson(["view", pkg, "versions", "--json"], cwd);
  return versions.filter((v) => STABLE.test(v)).sort(compareSemver);
}

async function packVersion(pkg, version, cwd) {
  const pack = await npmJson(["pack", `${pkg}@${version}`, "--json"], cwd);
  return path.join(cwd, pack[0].filename);
}

async function readResiFromTar(tgzPath, filePaths, cwd) {
  for (const filePath of filePaths) {
    try {
      const { stdout } = await execFile("tar", ["-xOf", tgzPath, filePath], {
        cwd,
        maxBuffer: 64 * 1024 * 1024,
      });
      return { content: stdout, resolvedPath: filePath };
    } catch {
      // Try next candidate path.
    }
  }
  throw new Error(`No .resi match in ${tgzPath}. Tried: ${filePaths.join(", ")}`);
}

function formatSymbol(key) {
  const [kind, name] = key.split(":");
  return `${kind} ${name}`;
}

function buildSince(releases, symbolsByRelease, sourceOrder) {
  const all = new Set();
  for (const symbols of symbolsByRelease.values()) {
    for (const symbol of symbols) all.add(symbol);
  }

  const ordered = [...releases].sort((a, b) => compareRelease(a, b, sourceOrder));
  const since = [];
  for (const symbol of [...all].sort()) {
    const first = ordered.find((release) =>
      symbolsByRelease.get(release.id)?.has(symbol)
    );
    since.push({
      symbol,
      sinceSource: first.source,
      sinceExact: first.version,
      sinceMinor: minorKey(first.version),
    });
  }
  return since;
}

function markdownReport(label, releases, snapshots, symbolsByRelease, sinceRows, sourceOrder) {
  const lines = [];
  lines.push(`# ${label}`);
  lines.push("");
  lines.push("Stable versions only (`x.y.z`, no alpha/beta/canary).");
  lines.push("");
  lines.push("## Presence by minor snapshot");
  lines.push("");
  lines.push("| package | minor snapshot | inspected patch | symbols present |");
  lines.push("| --- | --- | --- | --- |");
  for (const release of snapshots.sort((a, b) => compareRelease(a, b, sourceOrder))) {
    const symbols = [...(symbolsByRelease.get(release.id) ?? new Set())]
      .sort()
      .map(formatSymbol)
      .join(", ");
    lines.push(
      `| ${release.source} | ${minorKey(release.version)} | ${release.version} | ${symbols} |`
    );
  }
  lines.push("");
  lines.push("## Derived since values");
  lines.push("");
  lines.push("| symbol | package | since (exact) | since (minor) |");
  lines.push("| --- | --- | --- | --- |");
  for (const row of sinceRows) {
    lines.push(
      `| ${formatSymbol(row.symbol)} | ${row.sinceSource} | ${row.sinceExact} | ${row.sinceMinor} |`
    );
  }
  lines.push("");
  lines.push("## Stable versions inspected");
  lines.push("");
  const grouped = new Map();
  for (const release of releases) {
    const list = grouped.get(release.source) ?? [];
    list.push(release.version);
    grouped.set(release.source, list);
  }
  for (const [source, versions] of grouped.entries()) {
    lines.push(`- ${source}: ${versions.join(", ")}`);
  }
  lines.push("");
  return lines.join("\n");
}

async function auditPackage({ id, label, sources }, workspace, outputDir) {
  const sourceOrder = new Map(sources.map((source, idx) => [source.name, idx]));
  const releases = [];
  const symbolsByRelease = new Map();
  const pathsByRelease = {};

  for (const source of sources) {
    const versions = await getStableVersions(source.name, workspace);
    for (const version of versions) {
      const tgzPath = await packVersion(source.name, version, workspace);
      const { content: resi, resolvedPath } = await readResiFromTar(
        tgzPath,
        source.resiPaths,
        workspace
      );
      const release = {
        id: `${source.name}@${version}`,
        source: source.name,
        version,
      };
      releases.push(release);
      symbolsByRelease.set(release.id, parseExports(resi));
      pathsByRelease[release.id] = resolvedPath;
    }
  }

  releases.sort((a, b) => compareRelease(a, b, sourceOrder));
  const snapshots = collectMinorSnapshots(releases, sourceOrder);
  const sinceRows = buildSince(releases, symbolsByRelease, sourceOrder);
  const report = markdownReport(
    label,
    releases,
    snapshots,
    symbolsByRelease,
    sinceRows,
    sourceOrder
  );

  await writeFile(path.join(outputDir, `${id}-since.md`), report, "utf8");
  await writeFile(
    path.join(outputDir, `${id}-since.json`),
    JSON.stringify(
      {
        audit: label,
        releases,
        resiPathByRelease: pathsByRelease,
        minorSnapshots: snapshots.map((release) => ({
          package: release.source,
          version: release.version,
        })),
        since: sinceRows,
      },
      null,
      2
    ),
    "utf8"
  );

  return { label, releases: releases.length, symbols: sinceRows.length };
}

async function main() {
  const here = path.dirname(fileURLToPath(import.meta.url));
  const root = path.resolve(here, "..");
  const workDir = path.join(root, ".tmp", "version-audit");
  const outputDir = path.join(workDir, "results");

  await mkdir(workDir, { recursive: true });
  await mkdir(outputDir, { recursive: true });

  const done = [];
  for (const audit of AUDITS) {
    done.push(await auditPackage(audit, workDir, outputDir));
  }

  console.log(`Wrote reports to ${outputDir}`);
  for (const item of done) {
    console.log(`- ${item.label}: ${item.releases} stable releases, ${item.symbols} symbols`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
