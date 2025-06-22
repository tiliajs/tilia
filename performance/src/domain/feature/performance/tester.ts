import type { Experiment } from "@entity/experiment.type";
import type { GraphSetting } from "@entity/graph-setting.type";
import type { Graph } from "@feature/graph";
import type { Tester } from "@feature/tester";
import { computed, tilia } from "tilia";

export function make(
  graph: Graph,
  setting: GraphSetting,
  experiment: Experiment
) {
  const start = performance.now();
  graph.setup(setting);
  const setup = performance.now() - start;

  const p: Tester = tilia({
    setting,
    experiment,
    measures: [],
    graph,
    setup,
    avg: computed(() => avg(p.measures)),

    run() {
      p.measure();
    },
    measure() {
      p.measures = [];
      // Warmup
      // graph.run();

      let value = { sum: -1, rng: 0 };
      while (p.measures.length < p.experiment.repeat) {
        (globalThis as any).gc();
        const start = performance.now();
        value = graph.run();
        const elapsed = performance.now() - start;
        p.measures.push(elapsed);
      }
      return { elapsed: p.avg, value: value.sum, rng: value.rng };
    },
  });
  return p;
}

// Helpers

function avg(arr: number[]): number {
  if (arr.length === 0) throw new Error("No value to average");
  return arr.reduce((acc, a) => acc + a, 0) / arr.length;
}
