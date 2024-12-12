declare const o: unique symbol;
export type observer = { readonly [o]: true };
export function tilia<a extends object>(tree: a): a;
export function observe<a>(tree: a, fn: (tree: a) => void): void;
export function _connect<a>(tree: a, callback: () => void): observer;
export function _flush(observer: observer): void;
export function _clear(observer: observer): void;
