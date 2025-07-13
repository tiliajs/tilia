export type Loaded<T> = { t: "Loaded"; value: T };

export type Void = void | Promise<void>;

export type Loadable<T> = { t: "Blank" } | { t: "Loading" } | Loaded<T>;

export function isLoaded<T>(data: Loadable<T>): data is Loaded<T> {
  return data.t === "Loaded";
}

export function loaded<T>(value: T): Loaded<T> {
  return { t: "Loaded", value };
}

export function loading<T>(): Loadable<T> {
  return { t: "Loading" };
}

export function blank(): { t: "Blank" } {
  return { t: "Blank" };
}
