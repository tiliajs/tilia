import type { AppError, AppNotAuthenticated, AppReady } from "@interface/app";
import { todosFilterValues } from "@interface/todos";
import type { Todo } from "@model/todo";
import { useTilia } from "@tilia/react";
import {
  CheckCircle,
  Circle,
  Edit,
  LogIn,
  LogOut,
  Moon,
  Sparkles,
  Sun,
  Trash2,
} from "lucide-react";
import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
} from "react";
import { app_ } from "src/boot";

export function App() {
  return (
    <Layout>
      <AppSwitch />
    </Layout>
  );
}

function AppSwitch() {
  useTilia();
  const app = app_.value;
  switch (app.t) {
    case "NotAuthenticated":
      return <NotAuthenticatedApp app={app} />;
    case "Loading":
      return <LoadingApp />;
    case "Ready":
      return <ReadyApp app={app} />;
    case "Error":
      return <ErrorApp app={app} />;
  }
}

function Layout({ children }: { children: React.ReactNode }) {
  useTilia();
  const {
    display: { darkMode, setDarkMode },
    auth,
  } = app_.value;

  // <div className="min-h-screen transition-colors duration-300 bg-gray-900 text-pink-200 flex flex-col items-center justify-center">
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
            <a href="http://tiliajs.com">
              <span
                className={`${darkMode ? "text-pink-300" : "text-pink-500"}`}
              >
                Tilia
              </span>
            </a>
            <Sparkles
              className={`ml-2 ${darkMode ? "text-pink-300" : "text-pink-500"}`}
              size={24}
            />
            <span
              className={`ml-2 ${
                darkMode ? "text-purple-300" : "text-purple-500"
              }`}
            >
              todo
            </span>
          </h1>
          <div className="ml-6 flex flex-row items-center space-between">
            <button
              onClick={() => setDarkMode(!darkMode)}
              className={`p-2 cursor-pointer rounded-full ${
                darkMode
                  ? "bg-gray-800 text-pink-300"
                  : "bg-pink-100 text-pink-600"
              }`}
            >
              {darkMode ? <Sun size={20} /> : <Moon size={20} />}
            </button>
            <div className="p-2 rounded-full">
              {auth.t === "Authenticated" ? (
                <button
                  onClick={() => auth.logout()}
                  className={`p-2 rounded-full cursor-pointer ${
                    darkMode
                      ? "bg-gray-800 text-pink-300"
                      : "bg-pink-100 text-pink-600"
                  }`}
                >
                  <LogOut size={20} />
                </button>
              ) : (
                <button
                  onClick={() => auth.login({ id: "main", name: "Main" })}
                  className={`p-2 rounded-full cursor-pointer ${
                    darkMode
                      ? "bg-gray-800 text-pink-300"
                      : "bg-pink-100 text-pink-600"
                  }`}
                >
                  <LogIn size={20} />
                </button>
              )}
            </div>
          </div>
        </div>
        {children}
      </div>
    </div>
  );
}

function Modal(props: { children: React.ReactNode; onClick?: () => void }) {
  return (
    <div
      className="flex flex-col items-center justify-center border-2 border-pink-500 p-4 rounded-lg bg-pink-900 text-pink-600 cursor-pointer"
      onClick={props.onClick}
    >
      {props.children}
    </div>
  );
}

function LoadingApp() {
  return <Modal>Loading...</Modal>;
}

function ErrorApp({ app }: { app: AppError }) {
  useTilia();
  return <Modal>Error: {app.error}</Modal>;
}

function NotAuthenticatedApp({ app }: { app: AppNotAuthenticated }) {
  useTilia();
  const { auth } = app;
  return (
    <Modal onClick={() => auth.login({ id: "main", name: "Main" })}>
      <div>{auth.t}</div>
      <div>Click to Login</div>
    </Modal>
  );
}

const appContext = createContext<AppReady>({} as AppReady);
const AppProvider = appContext.Provider;
const useApp = () => {
  useTilia();
  return useContext(appContext);
};

export function ReadyApp({ app }: { app: AppReady }) {
  useTilia();
  const { todos, display } = app;
  const darkMode = display.darkMode;

  return (
    <AppProvider value={app}>
      <>
        {/* Add Todo Input */}
        <div className="mb-6">
          <div className="flex">
            <input
              type="text"
              value={todos.selected.title}
              onChange={(e: ChangeEvent<HTMLInputElement>) =>
                todos.setTitle(e.target.value)
              }
              placeholder="Add a task..."
              className={`flex-grow p-3 rounded-l-lg border-2 focus:outline-none ${
                darkMode
                  ? "bg-gray-800 border-pink-500 text-pink-100 placeholder-pink-300"
                  : "bg-white border-pink-300 text-gray-800 placeholder-pink-300"
              }`}
              onKeyDown={(e: React.KeyboardEvent<HTMLInputElement>) => {
                if (e.key === "Enter") {
                  todos.save(todos.selected);
                } else if (e.key === "Escape") {
                  todos.clear();
                }
              }}
            />
            <button
              onClick={() => todos.save(todos.selected)}
              className={`px-4 py-2 rounded-r-lg font-bold min-w-20 ${
                darkMode
                  ? "bg-pink-600 hover:bg-pink-700 text-white"
                  : "bg-pink-400 hover:bg-pink-500 text-white"
              }`}
            >
              {todos.selected.id === "" ? "Add" : "Save"}
            </button>
          </div>
        </div>

        <div className="flex justify-center space-x-2 mb-6">
          {todosFilterValues.map((f) => (
            <button
              key={f}
              onClick={() => todos.setFilter(f)}
              className={`px-4 py-2 rounded-full capitalize transition-colors ${
                todos.filter === f
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

        <TodoList />

        {todos.list.length > 0 && (
          <div className="mt-6 text-center">
            <p className={`${darkMode ? "text-pink-300" : "text-pink-500"}`}>
              {todos.remaining} tasks remaining
            </p>
          </div>
        )}
      </>
    </AppProvider>
  );
}

export function TodoList() {
  const {
    todos,
    display: { darkMode },
  } = useApp();

  return (
    <ul className="space-y-3">
      {todos.list.length > 0 ? (
        todos.list.map((todo) => <TodoView key={todo.id} todo={todo} />)
      ) : (
        <div
          className={`text-center p-6 rounded-lg ${
            darkMode ? "bg-gray-800" : "bg-white"
          }`}
        >
          <p className="text-lg">No tasks found!</p>
          <p className={`${darkMode ? "text-pink-400" : "text-pink-500"} mt-2`}>
            {todos.filter === "all"
              ? "Add some pinky tasks above!"
              : todos.filter === "active"
              ? "No active tasks!"
              : "No completed tasks!"}
          </p>
        </div>
      )}
    </ul>
  );
}

function TodoView({ todo }: { todo: Todo }) {
  const {
    todos,
    display: { darkMode },
  } = useApp();

  return (
    <li
      key={todo.id}
      className={`px-4 flex-grow flex items-center justify-between rounded-lg transition-all ${
        darkMode ? "bg-gray-800 hover:bg-gray-700" : "bg-white shadow" // hover:bg-pink-50 shadow"
      } ${
        todos.selected.id === todo.id ? "border-pink-500 border inset-0" : ""
      }`}
    >
      <button
        onClick={() => todos.toggle(todo.id)}
        className={`p-4 pr-1 cursor-pointer ${
          todo.completed
            ? darkMode
              ? "text-pink-400"
              : "text-pink-500"
            : darkMode
            ? "text-gray-500"
            : "text-gray-400"
        }`}
      >
        {todo.completed ? <CheckCircle size={20} /> : <Circle size={20} />}
      </button>
      <TodoTitle todo={todo} />
      <button
        onClick={(e) => {
          e.stopPropagation();
          todos.edit(todo);
        }}
        className={`p-4 text-gray-400 hover:${
          darkMode ? "text-pink-400" : "text-pink-500"
        }`}
      >
        <Edit size={18} />
      </button>
      <button
        onClick={(e) => {
          e.stopPropagation();
          todos.remove(todo.id);
        }}
        className={`opacity-40 hover:opacity-100 cursor-pointer text-gray-400 hover:${
          darkMode ? "text-pink-400" : "text-pink-500"
        }`}
      >
        <Trash2 size={18} />
      </button>
    </li>
  );
}

function TodoTitle({ todo }: { todo: Todo }) {
  const {
    todos,
    display: { darkMode },
  } = useApp();
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(todo.title);
  const inputRef = useRef<HTMLInputElement>(null);
  const changed = useRef(false);

  function finishEdit() {
    if (changed.current) {
      todo.title = title;
      todos.save(todo);
    }
    setEditing(false);
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") {
      finishEdit();
    } else if (e.key === "Escape") {
      setEditing(false);
    }
  }

  function handleChange(e: ChangeEvent<HTMLInputElement>) {
    changed.current = true;
    setTitle(e.target.value);
  }

  useEffect(() => {
    if (editing) {
      inputRef.current?.focus();
      // inputRef.current?.select();
    }
  }, [editing]);

  return (
    <div
      className="flex-grow"
      onClick={() => {
        if (!editing) {
          setTitle(todo.title);
          setEditing(true);
        }
      }}
    >
      {editing ? (
        <input
          ref={inputRef}
          onKeyDown={handleKeyDown}
          onChange={handleChange}
          onBlur={finishEdit}
          value={title}
          className={` w-full p-2 font-bold border-pink-200 border-2 outline-none rounded-xl font-inherit text-inherit ${
            darkMode ? "bg-gray-800" : "bg-white"
          }
          `}
          style={{ font: "inherit" }}
        />
      ) : (
        <div
          className={`p-2 border-2 border-transparent ${
            todo.completed
              ? `line-through ${darkMode ? "text-gray-500" : "text-gray-400"}`
              : ""
          }`}
        >
          {todo.title}
        </div>
      )}
    </div>
  );
}
