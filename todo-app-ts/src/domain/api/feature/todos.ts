import type { Signal } from "tilia";
import type { Loadable, Void } from "../model/loadable";
import type { Todo } from "../model/todo";

export type TodosFilter = "all" | "active" | "completed";

export const todosFilterValues: TodosFilter[] = ["all", "active", "completed"];

// Todos port (contract)
export interface Todos {
  // State
  filter: TodosFilter;
  selected: Todo;

  // Private
  readonly data_: Signal<Loadable<Todo[]>>;
  // Computed state
  readonly list: Loadable<Todo[]>;
  readonly remaining: number;

  // Operations
  save: (todo: Todo) => Void;
  clear: () => Void;
  remove: (id: string) => Void;
  edit: (todo: Todo) => Void;
  setTitle: (title: string) => Void;
  setFilter: (filter: TodosFilter) => Void;
  toggle: (id: string) => Void;
}
