import { useState, useEffect } from "react";
import { _observe, _ready, _clear } from "tilia";

export function useTilia(p) {
  const [, setCount] = useState(0);
  const o = _observe(p, () => setCount((i) => i + 1));
  useEffect(function () {
    _ready(o);
    return () => _clear(o);
  });
  return p;
}
