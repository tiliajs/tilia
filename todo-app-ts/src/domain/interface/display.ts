import type { Result } from "./repo";

export type Settings = {};

export type Display = {
  darkMode: boolean;

  // Operations
  setDarkMode: (darkMode: boolean) => Promise<Result<boolean>>;
};
