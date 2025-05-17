import type { Result } from "./store";

export type TodosFilter = "all" | "active" | "completed";
export const todosFilterValues: TodosFilter[] = ["all", "active", "completed"];

export type Settings = {
  todos: TodosFilter;
  darkMode: boolean;
};

export type Display = {
  settings: Settings;
  setFilters: (filters: Settings) => Promise<Result<Settings>>;
};
