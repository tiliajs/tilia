import type { Graph } from "@feature/graph";
import type { Experiment } from "@model/experiment";
import type { GraphSetting } from "@model/graph-setting";

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
