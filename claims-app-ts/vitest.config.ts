import { epureVitest } from "@epure/vitest";

export default {
  plugins: [epureVitest()],
  test: {
    include: ["test/**/*.feature", "test/**/*.test.ts"],
  },
};
