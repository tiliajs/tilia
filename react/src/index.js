import { useState, useEffect } from "react";
import { _connect, _ready, clear } from "@tilia/core";
export { tilia, observe, track, clear } from "@tilia/core";

export function useTilia(p) {
  const [, setCount] = useState(0);
  const o = _connect(p, () => setCount((i) => i + 1));
  useEffect(function () {
    _ready(o);
    return () => clear(o);
  });
  return p;
}
