declare const o: unique symbol;
export type observer = { readonly [o]: true };
export function tilia<a extends object>(tree: a): a;
export function observe<a>(tree: a, fn: (tree: a) => void): void;
export function track<a>(tree: a, fn: (tree: a) => void): observer;
export function clear(observer: observer): void;
export function _connect<a>(tree: a, callback: () => void): observer;
export function _ready(observer: observer, notifyIfChanged: boolean = true): void;
export function _meta<a>(tree: a): unknown;
