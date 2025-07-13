import type { Todo } from "@entity/todo";
import type { AppError, AppNotAuthenticated, AppReady } from "@feature/app";
import { todosFilterValues } from "@feature/todos";
import { useComputed, useTilia } from "@tilia/react";
import {
  CheckCircle,
  Circle,
  Edit,
  LogOut,
  Moon,
  Sparkles,
  Sun,
  Trash2,
} from "lucide-react";
import {
  createContext,
  memo,
  useContext,
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type FunctionComponent,
  type NamedExoticComponent,
} from "react";
import { app_ } from "src/boot";
import { Authentication } from "src/view/Authentication";
import { _clear, _done, _observe, _ready, tilia } from "tilia";

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
    case "Loading": // continue
    case "Blank":
      // To avoid rendering flash.
      return null;
    case "NotAuthenticated":
      return <NotAuthenticatedApp app={app} />;
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

  return (
    <div
      className={`min-h-screen transition-colors duration-300 ${
        darkMode ? "bg-gray-900 text-pink-200" : "bg-pink-50 text-gray-800"
      }`}
    >
      <div className="max-w-md mx-auto p-6">
        {/* Header */}
        <div className="flex justify-between items-center mb-1">
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
            {auth.t === "Authenticated" && (
              <button
                onClick={() => auth.logout()}
                className={`ml-4 p-2 rounded-full cursor-pointer ${
                  darkMode
                    ? "bg-gray-800 text-pink-300"
                    : "bg-pink-100 text-pink-600"
                }`}
              >
                <LogOut size={20} />
              </button>
            )}
          </div>
        </div>
        <div
          className={`text-sm flex justify-between m-2 mb-6 ${
            darkMode ? "text-pink-300" : "text-pink-500"
          }`}
        >
          <div className="flex flex-row">
            <span>
              <span className="opacity-70">demo app using</span>
              &nbsp;
              <a
                href="https://tiliajs.com"
                className="underline text-blue-200 cursor-pointer opacity-70 hover:opacity-100"
              >
                tilia
              </a>
              <span className="opacity-70">, view</span>
            </span>
            &nbsp;
            <a
              href="https://github.com/tiliajs/tilia/tree/main/todo-app-ts"
              className="underline text-blue-200 cursor-pointer opacity-70 hover:opacity-100"
            >
              source code
            </a>
          </div>
          <span>{auth.t === "Authenticated" ? auth.user.name : ""}</span>
        </div>
        <div
          className={`text-sm flex justify-between m-2 mb-6 ${
            darkMode ? "text-pink-300" : "text-pink-500"
          }`}
        >
          <div className="inline-flex items-center gap-2">
            <span className="opacity-70">the little dot</span>
            <span className="border border-black bg-white rounded-full w-2 h-2" />
            <span className="opacity-70">
              indicates that a component re-renders
            </span>
          </div>
        </div>
        {children}
      </div>
    </div>
  );
}

function Modal(props: { children: React.ReactNode; onClick?: () => void }) {
  return (
    <div className="flex flex-col items-center">
      <div className="text-center m-4">Select an option</div>
      <div
        className="flex flex-col items-center justify-center border border-cyan-500 p-4 rounded-lg bg-cyan-200/30 text-pink-600 drop-shadow-2xl drop-shadow-yellow-200/30"
        onClick={props.onClick}
      >
        {props.children}
      </div>
    </div>
  );
}

function ErrorApp({ app }: { app: AppError }) {
  useTilia();
  return <Modal>Error: {app.error}</Modal>;
}

function NotAuthenticatedApp({ app }: { app: AppNotAuthenticated }) {
  useTilia();
  const { auth } = app;
  return (
    <Modal>
      <Authentication auth={auth} />
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

  return (
    <AppProvider value={app}>
      <>
        <TodoInput />

        <FilterValues />

        <TodoList />

        <Remaining />

        <LeakTest />
      </>
    </AppProvider>
  );
}

function LeakTest() {
  return null;

  return (
    <div className="mt-6">
      <button onClick={leakTest} className="cursor-pointer">
        leak test
      </button>
    </div>
  );
}

function FilterValues() {
  const {
    display: { darkMode },
    todos,
  } = useApp();
  return (
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
  );
}

function TodoInput() {
  const {
    todos,
    display: { darkMode },
  } = useApp();
  const blink = useBlink();

  return (
    <div className="mb-6">
      <div className="flex">
        {blink}
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
  );
}

export function TodoList() {
  const {
    todos: { list, filter },
    display: { darkMode },
  } = useApp();

  return (
    <ul className="space-y-3">
      {list.length > 0 ? (
        list.map((todo) => <TodoView key={todo.id} todo={todo} />)
      ) : (
        <div
          className={`text-center p-6 rounded-lg ${
            darkMode ? "bg-gray-800" : "bg-white"
          }`}
        >
          <p className="text-lg">No tasks found!</p>
          <p className={`${darkMode ? "text-pink-400" : "text-pink-500"} mt-2`}>
            {filter === "all"
              ? "Add some pinky tasks above!"
              : filter === "active"
              ? "No active tasks!"
              : "No completed tasks!"}
          </p>
        </div>
      )}
    </ul>
  );
}

function Remaining() {
  const {
    display: { darkMode },
    todos: { list, remaining },
  } = useApp();
  const blink = useBlink();

  return (
    <div className="mt-6 flex flex-row justify-center items-center gap-4">
      {list.length > 0 && (
        <p className={darkMode ? "text-pink-300" : "text-pink-500"}>
          {remaining} tasks remaining
        </p>
      )}
      {blink}
    </div>
  );
}

const TodoView = view(function TodoView({ todo }: { todo: Todo }) {
  const {
    todos,
    display: { darkMode },
  } = useContext(appContext);
  const blink = useBlink();

  const selected = useComputed(() => todos.selected.id === todo.id);

  return (
    <li
      key={todo.id}
      className={`px-4 flex-grow flex items-center justify-between rounded-lg transition-all border ${
        darkMode ? "bg-gray-800 hover:bg-gray-700" : "bg-white shadow" // hover:bg-pink-50 shadow"
      } ${
        //  This is an anti-pattern...
        selected.value ? "border-pink-500" : "border-transparent"
      }`}
    >
      {blink}
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
          todos.edit(todo.id);
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
});

function TodoTitle({ todo }: { todo: Todo }) {
  const {
    todos,
    display: { darkMode },
  } = useApp();
  const blink = useBlink();

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
      className="flex-grow relative"
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
      <div className="absolute top-1/2 right-4 opacity-30">{blink}</div>
    </div>
  );
}

function useBlink() {
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;

    node.style.backgroundColor = "#FFFF";
    const timeout = setTimeout(() => {
      node.style.backgroundColor = "#0009";
    }, 150);

    return () => clearTimeout(timeout);
  });

  return (
    <span
      ref={ref}
      style={{
        display: "inline-block",
        width: "8px",
        height: "8px",
        border: "1px solid black",
        borderRadius: "10px",
        transition: "background 0.15s",
      }}
    >
      &nbsp;
    </span>
  );
}

function leakTest() {
  const p = tilia<Record<string, number>>({});

  const o = _observe(() => {});
  for (let i = 1; i <= 1_000_000; ++i) {
    // Read with observer
    if (p[String(i)] !== undefined) {
      console.log(p[String(i)], "is not undefined");
    }
    // Write
    p[String(i)] = i;
    _ready(o, true);
    _clear(o);
    for (let j = 1; j <= 100; ++j) {
      // Read without observer
      p[String(i)];
    }
    delete p[String(i)];
  }
  console.log("done");
}

// Example on how to create a HOC that does the same as useTilia.
function view<T extends object>(
  fn: FunctionComponent<T>
): NamedExoticComponent<T> {
  function fun(p: T) {
    const [_, setCount] = useState(0);
    // Start observing
    const o = _observe(() => setCount((i) => i + 1));
    useEffect(() => {
      // Ready for notifications
      _ready(o, true);
      return () => _clear(o);
    });
    const res = fn(p);
    // End observing
    _done(o);
    return res;
  }
  const fnx = memo(fun);
  fnx.displayName = (fn.displayName || fn.name).replace(/\d+$/, "");
  return fnx;
}

/*
function view<T extends object>(
  fn: FunctionComponent<T>
): FunctionComponent<T> {
  const name = fn.displayName || fn.name;
  const obj = {
    [name]: function (props: T) {
      const [_, setCount] = useState(0);
      const o = _observe(() => setCount((i) => i + 1));
      useEffect(() => {
        _ready(o, true);
        return () => _clear(o);
      });
      const res = fn(props);
      _done(o);
      return res;
    },
  };
  return obj[name];
}
*/
