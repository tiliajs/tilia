import type { GraphSetting } from "@entity/graph-setting.type";
import type { Tester } from "@feature/tester";
import { jotaiGraph } from "src/domain/feature/performance/jotai-graph";
import { rxjsGraph } from "src/domain/feature/performance/rxjs-graph";
import { make } from "src/domain/feature/performance/tester";
import { tiliaG } from "src/domain/feature/performance/tilia-graph";
import { random } from "src/service/random";
import type { Experiment } from "./domain/api/entity/experiment.type";

// https://github.com/tsurucapital/frp-benchmarks
const graphs: GraphSetting[] = [
  /** MINIMAL SETUP WHERE JOTAI RETURNS ANOTHER VALUE 
   * 
  {
    title: "Dynamic graph TEST",
    seed: 31415926,
    users: 1,
    usersFolders: 5,
    folders: 5,
    foldersFiles: 3,
    files: 10,
    updates: 0,
    swaps: 1,
    steps: 2,
  },
  */
  {
    title: "Fixed graph",
    seed: 31415926,
    users: 1,
    usersFolders: 1,
    folders: 1,
    foldersFiles: 1000,
    files: 1000,
    updates: 10,
    swaps: 0,
    steps: 100,
  },
  {
    title: "File swaps",
    seed: 31415926,
    users: 1,
    usersFolders: 50,
    folders: 50,
    foldersFiles: 40,
    files: 1000,
    updates: 10,
    swaps: 10,
    steps: 100,
  },
  {
    title: "Dynamic graph",
    seed: 31415926,
    users: 20,
    usersFolders: 10,
    folders: 30,
    foldersFiles: 80,
    files: 1000,
    updates: 10,
    swaps: 30,
    steps: 100,
  },
];

function test() {
  for (const graph of graphs) {
    const tests = setup(graph, {
      repeat: 1,
    });
    run(tests);
  }
}

function log(s: GraphSetting, raw: Result[]) {
  const results = [...raw].sort((a, b) => a.elapsed - b.elapsed);
  console.log(`
┌────── RESULT ${(s.title + " ").padEnd(34, "─")}──────┐
│ users                │ ${pad(s.users) /*  */} user(s)               │
│ users   ──── folders │ ${pad(s.usersFolders)} link(s)               │
│ folders              │ ${pad(s.folders) /**/} folder(s)             │
│ folders ──── files   │ ${pad(s.foldersFiles)} link(s)               │
│ files                │ ${pad(s.files) /*  */} file(s)               │
│ updates / step       │ ${pad(s.updates) /**/} updates               │
│ swaps   / step       │ ${pad(s.swaps) /*  */} file swap             │
│ steps                │ ${pad(s.steps) /*  */} times                 │
├──────────────────────┼──────────┬───────┬────────────┤`);
  for (const r of results) {
    console.log(
      `│ ${r.library.padEnd(20)} │ ${pad(r.value.toFixed(2), 8)} │ ${pad(
        r.rng.toFixed(3),
        5
      )} │ ${timing(r.elapsed, 7) /*    */} │`
    );
  }
  console.log("└──────────────────────┴──────────┴───────┴────────────┘");
}

function timing(n: number, len: number) {
  if (n > Math.pow(10, len - 2)) {
    return `${pad((n / 1000).toFixed(0), len)} s `;
  } else {
    return `${pad(n.toFixed(0), len)} ms`;
  }
}

function pad(n: number | string, len = 7) {
  return n.toString().padStart(len, " ");
}

function setup(setting: GraphSetting, experiment: Experiment) {
  const performances: Tester[] = [];
  // Warmup
  // for (const graph of [tiliaG(true), tiliaG(false), jotaiGraph, rxjsGraph]) {
  //   const g = graph(random);
  //   make(g, setting, experiment);
  // }

  for (const graph of [tiliaG(true), tiliaG(false), jotaiGraph, rxjsGraph]) {
    const g = graph(random);
    const p = make(g, setting, experiment);
    performances.push(p);
  }
  return performances;
}

function run(tests: Tester[]) {
  const results: Result[] = [];

  for (const t of tests) {
    const r = t.measure();
    results.push({ library: t.graph.library, ...r });
  }
  log(tests[0].setting, results);
}

interface Result {
  library: string;
  elapsed: number;
  value: number;
  rng: number;
}

test();
