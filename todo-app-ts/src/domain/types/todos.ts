import type { Loadable, Void } from "./loadable";

export type Todo = {
  id: string;
  userId: string;
  title: string;
  completed: boolean;
};

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
