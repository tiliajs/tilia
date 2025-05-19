import { isSuccess, type Store } from "@interface/store";
import type { Todos } from "@interface/todos";
import { isLoaded } from "@model/loadable";

export async function remove(store: Store, todos: Todos, id: string) {
  if (isLoaded(todos.data)) {
    const result = await store.removeTodo(id);
    if (isSuccess(result)) {
      todos.data.value = todos.data.value.filter((t) => t.id !== id);
    }
    // FIXME: handle error
  }
}
