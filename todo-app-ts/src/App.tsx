import { useTilia } from "@tilia/react";
import { CheckCircle, Circle, Moon, Sparkles, Sun, Trash2 } from "lucide-react";
import { useState, type ChangeEvent, type KeyboardEvent } from "react";
import { app } from "./domain/app";
import { todosFilterValues } from "./domain/types/display";
import { isLoaded } from "./domain/types/loadable";

export default function App() {
  const { todos, display } = useTilia(app);
  const [darkMode, setDarkMode] = useState<boolean>(false);

  // Toggle dark mode
  const toggleDarkMode = (): void => {
    setDarkMode(!darkMode);
  };

  return (
    <div
      className={`min-h-screen transition-colors duration-300 ${
        darkMode ? "bg-gray-900 text-pink-200" : "bg-pink-50 text-gray-800"
      }`}
    >
      <div className="max-w-md mx-auto p-6">
        {/* Header */}
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold flex items-center">
            <span className={`${darkMode ? "text-pink-300" : "text-pink-500"}`}>
              Pinky
            </span>
            <Sparkles
              className={`ml-2 ${darkMode ? "text-pink-300" : "text-pink-500"}`}
              size={24}
            />
            <span
              className={`ml-2 ${
                darkMode ? "text-purple-300" : "text-purple-500"
              }`}
            >
              Tasks
            </span>
          </h1>
          <button
            onClick={toggleDarkMode}
            className={`p-2 rounded-full ${
              darkMode
                ? "bg-gray-800 text-pink-300"
                : "bg-pink-100 text-pink-600"
            }`}
          >
            {darkMode ? <Sun size={20} /> : <Moon size={20} />}
          </button>
        </div>

        {/* Add Todo Input */}
        <div className="mb-6">
          <div className="flex">
            <input
              type="text"
              value={todos.selected.title}
              onChange={(e: ChangeEvent<HTMLInputElement>) =>
                todos.setTitle(e.target.value)
              }
              placeholder="Add a funky task..."
              className={`flex-grow p-3 rounded-l-lg border-2 focus:outline-none ${
                darkMode
                  ? "bg-gray-800 border-pink-500 text-pink-100 placeholder-pink-300"
                  : "bg-white border-pink-300 text-gray-800 placeholder-pink-300"
              }`}
              onKeyPress={(e: KeyboardEvent<HTMLInputElement>) => {
                if (e.key === "Enter") {
                  todos.save();
                }
              }}
            />
            <button
              onClick={() => todos.save()}
              className={`px-4 py-2 rounded-r-lg font-bold ${
                darkMode
                  ? "bg-pink-600 hover:bg-pink-700 text-white"
                  : "bg-pink-400 hover:bg-pink-500 text-white"
              }`}
            >
              Add
            </button>
          </div>
        </div>

        <div className="flex justify-center space-x-2 mb-6">
          {todosFilterValues.map((f) => (
            <button
              key={f}
              onClick={() =>
                display.setFilters({ ...display.filters, todos: f })
              }
              className={`px-4 py-2 rounded-full capitalize transition-colors ${
                display.filters.todos === f
                  ? darkMode
                    ? "bg-pink-600 text-white"
                    : "bg-pink-400 text-white"
                  : darkMode
                  ? "bg-gray-800 text-pink-300 hover:bg-gray-700"
                  : "bg-pink-100 text-pink-600 hover:bg-pink-200"
              }`}
            >
              {f}
            </button>
          ))}
        </div>

        <TodoList darkMode={darkMode} />

        {todos.list.length > 0 && (
          <div className="mt-6 text-center">
            <p className={`${darkMode ? "text-pink-300" : "text-pink-500"}`}>
              {todos.remaining} tasks remaining
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

export function TodoList({ darkMode }: { darkMode: boolean }) {
  const {
    todos,
    display: { filters },
    store,
  } = useTilia(app);

  if (!isLoaded(todos.data)) {
    return <div>store state: {store.state.t}</div>;
  }

  return (
    <ul className="space-y-3">
      {todos.list.length > 0 ? (
        todos.list.map((todo) => (
          <li
            key={todo.id}
            className={`flex items-center justify-between p-4 rounded-lg transition-all ${
              darkMode
                ? "bg-gray-800 hover:bg-gray-700"
                : "bg-white hover:bg-pink-50 shadow"
            }`}
          >
            <div className="flex items-center">
              <button
                onClick={() => todos.toggle(todo.id)}
                className={`mr-3 ${
                  todo.completed
                    ? darkMode
                      ? "text-pink-400"
                      : "text-pink-500"
                    : darkMode
                    ? "text-gray-500"
                    : "text-gray-400"
                }`}
              >
                {todo.completed ? (
                  <CheckCircle size={20} />
                ) : (
                  <Circle size={20} />
                )}
              </button>
              <span
                className={`${
                  todo.completed
                    ? `line-through ${
                        darkMode ? "text-gray-500" : "text-gray-400"
                      }`
                    : ""
                }`}
              >
                {todo.title}
              </span>
            </div>
            <button
              onClick={() => todos.remove(todo.id)}
              className={`text-gray-400 hover:${
                darkMode ? "text-pink-400" : "text-pink-500"
              }`}
            >
              <Trash2 size={18} />
            </button>
          </li>
        ))
      ) : (
        <div
          className={`text-center p-6 rounded-lg ${
            darkMode ? "bg-gray-800" : "bg-white"
          }`}
        >
          <p className="text-lg">No tasks found!</p>
          <p className={`${darkMode ? "text-pink-400" : "text-pink-500"} mt-2`}>
            {filters.todos === "all"
              ? "Add some pinky tasks above!"
              : filters.todos === "active"
              ? "No active tasks!"
              : "No completed tasks!"}
          </p>
        </div>
      )}
    </ul>
  );
}
