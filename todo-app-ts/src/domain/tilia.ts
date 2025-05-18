import { computed, make as makeTilia } from "tilia";

export function make(flush?: (fn: () => void) => void): Context {
  const { connect, observe } = makeTilia(flush);
  return { connect, observe, computed };
}

export type Context = {
  connect: <T>(t: T) => T;
  observe: (fn: () => void) => void;
  computed: <a>(fn: () => a) => a;
};
