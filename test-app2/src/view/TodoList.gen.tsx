/* TypeScript file generated from TodoList.res by genType. */

/* eslint-disable */
/* tslint:disable */

import * as TodoListJS from './TodoList.mjs';

import type {todos as Todo_todos} from '../../src/domain/Todo.gen';

export type props<todos> = { readonly todos: todos };

export const make: React.ComponentType<{ readonly todos: Todo_todos }> = TodoListJS.make as any;
