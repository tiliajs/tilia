import type { Result } from "./store";

export type TodosFilter = "all" | "active" | "completed";
export const todosFilterValues: TodosFilter[] = ["all", "active", "completed"];

export type Filters = {
  todos: TodosFilter;
};

export type Display = {
  filters: Filters;
  setFilters: (filters: Filters) => Promise<Result<Filters>>;
};
