import type { GraphSetting } from "@entity/graph-setting.type";

export type Data = {
  users: { value: number; sum: number; folders: number[] }[];
  folders: { value: number; sum: number; files: number[] }[];
  files: number[];
};

export interface Graph {
  library: string;
  // build the random graph
  setup: (setting: GraphSetting) => void;
  // run the random updates and return the graph sum
  run: () => { sum: number; rng: number };
  toData: () => Data;
}
