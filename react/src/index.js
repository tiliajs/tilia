import { useState, useEffect } from "react";
import { _connect, _ready, _clear, tilia, observe } from "@tilia/core";

export function useTilia(p) {
  const [, setCount] = useState(0);
  const o = _connect(p, () => setCount((i) => i + 1));
  useEffect(function () {
    _ready(o);
    return () => _clear(o);
  });
  return p;
}

export { tilia, observe };
