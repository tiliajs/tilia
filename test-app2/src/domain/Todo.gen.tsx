/* TypeScript file generated from Todo.res by genType. */

/* eslint-disable */
/* tslint:disable */

import * as TodoJS from './Todo.mjs';

export type todo = {
  readonly id: string; 
  readonly title: string; 
  completed: boolean
};

export type todos = {
  list: todo[]; 
  readonly add: (_1:todo) => void; 
  readonly toggle: (_1:string) => void; 
  readonly remove: (_1:string) => void; 
  readonly completedCount: number
};

export const makeTodo: (id:string, title:string) => todo = TodoJS.makeTodo as any;

export const make: () => todos = TodoJS.make as any;
