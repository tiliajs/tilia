import { createClient } from "@supabase/supabase-js";
import { update, type Setter, type Signal } from "tilia";
import { type Auth } from "../interface/auth";
import { fail, success, type Repo, type Result } from "../interface/repo";
import type { Todo } from "../model/todo";

const supabaseUrl = "https://bfrxzoliopayvesrmcoe.supabase.co";

const supabaseKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcnh6b2xpb3BheXZlc3JtY29lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgxMTY4MDgsImV4cCI6MjA2MzY5MjgwOH0.FVb8pBz8LWWjkgTjbXrxhNkl-yLRISYR4kK1NOuKqp0";
export const supabase = createClient(supabaseUrl, supabaseKey);

type SupabaseRepo = Repo & {
  db: typeof supabase;
};

export function supabaseRepo(auth_: Signal<Auth>): Signal<Repo> {
  return update<SupabaseRepo>(
    // Initial state
    { t: "NotAuthenticated", db: supabase },

    // Update function
    (repo, set) => {
      const auth = auth_.value;
      if (auth.t === "Blank") {
        // Wait to avoid flicker.
        return;
      }

      if (auth.t !== "Authenticated") {
        if (repo.t === "Ready") {
          // Sign out from Supabase when user becomes unauthenticated
          supabase.auth.signOut();
          set({ t: "Closed", db: repo.db });
        }
        return;
      }

      switch (repo.t) {
        case "Closed":
        case "NotAuthenticated": {
          set({ t: "Opening", db: repo.db });
          // Set up Supabase session and initialize repo
          initializeSupabaseRepo(set, auth.user.id);
          break;
        }
        case "Opened": {
          set({
            t: "Ready",
            db: repo.db,
            // Operations
            saveTodo: (todo) => saveTodo(repo, todo, auth.user.id),
            removeTodo: (id) => removeTodo(repo, id, auth.user.id),
            fetchTodos: () => fetchTodos(repo, auth.user.id),
            saveSetting: (key, value) =>
              saveSetting(repo, key, value, auth.user.id),
            fetchSetting: (key) => fetchSetting(repo, key, auth.user.id),
          });
          break;
        }
      }
    }
  );
}

const TODOS_TABLE = "todos";
const SETTINGS_TABLE = "settings";

async function saveTodo(
  repo: SupabaseRepo,
  atodo: Todo,
  userId: string
): Promise<Result<Todo>> {
  try {
    const todo: Todo = { ...atodo, userId };

    const { data, error } = await repo.db
      .from(TODOS_TABLE)
      .upsert(todo)
      .select()
      .single();

    if (error) {
      return fail(`Todo save failed: ${error.message}`);
    }

    return success(data as Todo);
  } catch (err) {
    return fail(
      `Todo save failed: ${
        err instanceof Error ? err.message : "Unknown error"
      }`
    );
  }
}

async function removeTodo(
  repo: SupabaseRepo,
  id: string,
  userId: string
): Promise<Result<string>> {
  try {
    const { error } = await repo.db
      .from(TODOS_TABLE)
      .delete()
      .eq("id", id)
      .eq("userId", userId);

    if (error) {
      return fail(`Todo delete failed: ${error.message}`);
    }

    return success(id);
  } catch (err) {
    return fail(
      `Todo delete failed: ${
        err instanceof Error ? err.message : "Unknown error"
      }`
    );
  }
}

async function fetchTodos(
  repo: SupabaseRepo,
  userId: string
): Promise<Result<Todo[]>> {
  try {
    const { data, error } = await repo.db
      .from(TODOS_TABLE)
      .select("*")
      .eq("userId", userId);

    if (error) {
      return fail(`Fetch todos failed: ${error.message}`);
    }

    return success(data as Todo[]);
  } catch (err) {
    return fail(
      `Fetch todos failed: ${
        err instanceof Error ? err.message : "Unknown error"
      }`
    );
  }
}

async function saveSetting(
  repo: SupabaseRepo,
  key: string,
  value: string,
  userId: string
): Promise<Result<string>> {
  try {
    const setting = {
      id: `${userId}_${key}`, // Composite key to ensure uniqueness per user`
      key,
      value,
      userId,
    };

    const { error } = await repo.db.from(SETTINGS_TABLE).upsert(setting);

    if (error) {
      return fail(`Setting save failed: ${error.message}`);
    }

    return success(value);
  } catch (err) {
    return fail(
      `Setting save failed: ${
        err instanceof Error ? err.message : "Unknown error"
      }`
    );
  }
}

async function fetchSetting(
  repo: SupabaseRepo,
  key: string,
  userId: string
): Promise<Result<string>> {
  try {
    const { data, error } = await repo.db
      .from(SETTINGS_TABLE)
      .select("value")
      .eq("key", key)
      .eq("userId", userId);
    if (error) {
      if (error.code === "PGRST116") {
        // No rows returned - setting doesn't exist
        return fail("Setting not found");
      }
      return fail(`Setting fetch failed: ${error.message}`);
    }

    return data.length > 0 ? success(data[0].value) : fail("Setting not found");
  } catch (err) {
    return fail(
      `Setting fetch failed: ${
        err instanceof Error ? err.message : "Unknown error"
      }`
    );
  }
}

// ======= PRIVATE ========================

async function initializeSupabaseRepo(
  set: Setter<SupabaseRepo>,
  userId: string
) {
  try {
    // Verify Supabase connection and user authentication
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError) {
      set({
        t: "Error",
        error: `Authentication error: ${authError.message}`,
        db: supabase,
      });
      return;
    }

    if (!user || user.id !== userId) {
      set({
        t: "Error",
        error: "User authentication mismatch",
        db: supabase,
      });
      return;
    }

    // Test database connectivity with a simple query
    const { error: testError } = await supabase
      .from(TODOS_TABLE)
      .select("id")
      .limit(1);

    if (testError) {
      set({
        t: "Error",
        error: `Database connection failed: ${testError.message}`,
        db: supabase,
      });
      return;
    }

    // Successfully connected
    set({ t: "Opened", db: supabase });
  } catch (err) {
    set({
      t: "Error",
      error: `Repository initialization failed: ${
        err instanceof Error ? err.message : "Unknown error"
      }`,
      db: supabase,
    });
  }
}

// Optional: Set up real-time subscriptions for todos
/*
export function setupRealtimeSubscription(
  repo: SupabaseRepo,
  userId: string,
  onTodoChange: (todos: Todo[]) => void
) {
  return repo.db
    .channel("todos-changes")
    .on(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: TODOS_TABLE,
        filter: `userId=eq.${userId}`,
      },
      () => {
        // Refetch todos when changes occur
        fetchTodos(repo, userId).then((result) => {
          if (result.t === "Success") {
            onTodoChange(result.data);
          }
        });
      }
    )
    .subscribe();
}
*/
