import type { Result } from "../service/repo";

export type Display = {
  darkMode: boolean;

  // Operations
  setDarkMode: (darkMode: boolean) => Promise<Result<boolean>>;
};
