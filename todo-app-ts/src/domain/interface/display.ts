import type { Result } from "./store";

export type Settings = {};

export type Display = {
  darkMode: boolean;

  // Operations
  setDarkMode: (darkMode: boolean) => Promise<Result<boolean>>;
};
