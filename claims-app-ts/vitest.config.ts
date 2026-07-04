import { vitestBdd } from "vitest-bdd";

export default {
  plugins: [vitestBdd()],
  test: {
    include: ["test/**/*.feature"],
  },
};
