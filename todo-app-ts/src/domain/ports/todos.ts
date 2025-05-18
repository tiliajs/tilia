import type { Loadable, Void } from "../types/loadable";
import type { Todo } from "../types/todo";

// Todos port (contract)
export type Todos = {
  // State
  data: Loadable<Todo[]>;
  list: Todo[];
  remaining: number;
  selected: Todo;

  // Operations
  save: (todo: Todo) => Void;
  clear: () => Void;
  remove: (id: string) => Void;
  edit: (todo: Todo) => Void;
  setTitle: (title: string) => Void;
  toggle: (id: string) => void;
};
