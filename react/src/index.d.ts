import type { observer } from "@tilia/core";
export function tilia<a extends object>(
  tree: a,
  flush?: (fn: () => void) => void
): a;
export function observe<a>(tree: a, fn: (tree: a) => void): void;
export function track<a>(tree: a, fn: (tree: a) => void): observer;
export function clear(observer: observer): void;
export const useTilia: <a>(tree: a) => a;
