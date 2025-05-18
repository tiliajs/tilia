import type { Loadable, Void } from "../types/loadable";
import type { Todo } from "../types/todo";

export type TodosFilter = "all" | "active" | "completed";

export const todosFilterValues: TodosFilter[] = ["all", "active", "completed"];

// Todos port (contract)
export type Todos = {
  // State
  filter: TodosFilter;
  data: Loadable<Todo[]>;
  list: Todo[];
  remaining: number;
  selected: Todo;

  // Operations
  save: (todo: Todo) => Promise<Todo>;
  clear: () => Void;
  remove: (id: string) => Void;
  edit: (todo: Todo) => Void;
  setTitle: (title: string) => Void;
  setFilter: (filter: TodosFilter) => void;
  toggle: (id: string) => void;
};
