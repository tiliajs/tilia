declare const o: unique symbol;
export type observer = { readonly [o]: true };
export function tilia<a extends object>(tree: a): a;
export function observe<a>(tree: a, fn: (tree: a) => void): void;
export function _connect<a>(tree: a, callback: () => void, notifyIfChanged: boolean = true): observer;
export function _ready(observer: observer): void;
export function _clear(observer: observer): void;
export function _meta<a>(tree: a): unknown;
