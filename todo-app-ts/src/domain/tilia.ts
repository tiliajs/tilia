import { computed, make as makeTilia } from "tilia";

export function make(): Context {
  const { connect, observe } = makeTilia();
  return { connect, observe, computed };
}

export type Context = {
  connect: <T>(t: T) => T;
  observe: (fn: () => void) => void;
  computed: <a>(fn: () => a) => a;
};
