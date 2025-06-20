import type { Experiment } from "@entity/experiment";
import type { GraphSetting } from "@entity/graph-setting";
import type { Graph } from "@feature/graph";

export interface Tester {
  setting: GraphSetting;
  experiment: Experiment;
  measures: number[];
  // The time it takes to setup the graph
  setup: number;
  graph: Graph;
  readonly avg: number;

  // Operations
  run: () => void;
  measure: () => { elapsed: number; value: number; rng: number };
}
