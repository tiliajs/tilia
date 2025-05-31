declare const o: unique symbol;
declare const r: unique symbol;
export type Observer = { readonly [o]: true };
export type Signal<a> = { value: a };
export type Setter<a> = (v: a) => void;
export type Tilia = {
  connect: <a>(branch: a) => a;
  computed: <a>(fn: () => a) => a;
  observe: (fn: () => void) => void;
  signal: <a>(v: a) => readonly [Signal<a>, (v: a) => void];
  derived: <a>(fn: () => a) => Signal<a>;
};
export function make(flush?: (fn: () => void) => void): Tilia;

// Default global context

export function connect<a>(branch: a): a;
export function computed<a>(fn: () => a): a;
export function observe(fn: () => void): void;

export function signal<a>(v: a): readonly [Signal<a>, (v: a) => void];
export function derived<a>(fn: () => a): Signal<a>;
export function _clear(observer: Observer): void;
export function _observe<a>(tree: a, callback: () => void): Observer;
export function _ready(observer: Observer, notifyIfChanged?: boolean): void;
export function _meta<a>(tree: a): unknown;
