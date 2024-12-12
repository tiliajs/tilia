/* TypeScript file generated from TiliaCore.resi by genType. */

/* eslint-disable */
/* tslint:disable */

import * as T from "./TiliaCore.mjs";
declare const o: unique symbol;
export type observer = { readonly [o]: true };

export const tilia: <a extends object>(tree: a) => a = T.make as any;
export const observe: <a>(tree: a, fn: (tree: a) => void) => void =
  T.observe as any;

/* INTERNAL TYPES FOR LIBRARY AUTHORS */
export const _connect: <a>(tree: a, callback: () => void) => observer =
  T._connect as any;
export const _flush: (observer: observer) => void = T._flush as any;
export const _clear: (observer: observer) => void = T._clear as any;
