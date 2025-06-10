import type { Loadable, Void } from "../model/loadable";
import type { Todo } from "../model/todo";
export type Signalx<T> = { valuex: T };

export type TodosFilter = "all" | "active" | "completed";

export const todosFilterValues: TodosFilter[] = ["all", "active", "completed"];

// Todos port (contract)
export interface Todos {
  // State
  filter: TodosFilter;
  selected: Todo;

  // Computed state
  data_: Signalx<Loadable<Todo[]>>;
  list: Loadable<Todo[]>;
  remaining: number;

  // Operations
  save: (todo: Todo) => Void;
  clear: () => Void;
  remove: (id: string) => Void;
  edit: (todo: Todo) => Void;
  setTitle: (title: string) => Void;
  setFilter: (filter: TodosFilter) => Void;
  toggle: (id: string) => Void;
}
