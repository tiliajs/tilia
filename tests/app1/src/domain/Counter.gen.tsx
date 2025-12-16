/* TypeScript file generated from Counter.res by genType. */

/* eslint-disable */
/* tslint:disable */

import * as CounterJS from './Counter.res.mjs';

export type counter = {
  value: number; 
  readonly double: number; 
  readonly increment: () => void; 
  readonly decrement: () => void
};

export const make: () => counter = CounterJS.make as any;
