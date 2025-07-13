import type { Void } from "@entity/loadable";
import type { Todo } from "@entity/todo";
import type { RepoReady } from "@service/repo";

export type TodosFilter = "all" | "active" | "completed";

export const todosFilterValues: TodosFilter[] = ["all", "active", "completed"];

// Todos port (contract)
export interface Todos {
  // State
  filter: TodosFilter;
  selected: Todo;

  // Computed state
  readonly list: Todo[];
  readonly remaining: number;

  // Operations
  save: (todo: Todo) => Void;
  clear: () => Void;
  remove: (id: string) => Void;
  edit: (id: string) => Void;
  setTitle: (title: string) => Void;
  setFilter: (filter: TodosFilter) => Void;
  toggle: (id: string) => Void;

  // Private
  readonly repo: RepoReady;
  data: Todo[];
}
