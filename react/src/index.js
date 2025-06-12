import { _ctx } from "tilia";
import { useMemo, useState, useEffect } from "react";

export function make({ _observe, _ready, _clear, tilia, computed }) {
  function useTilia() {
    const [_, setCount] = useState(0);
    const o = _observe(() => setCount((i) => i + 1));
    useEffect(() => {
      _ready(o, true);
      return () => _clear(o);
    });
  }
  function useComputed(fn) {
    return useMemo(() => tilia({ value: computed(fn) }), []);
  }
  return { useTilia, useComputed };
}

const tr = make(_ctx);
export const useTilia = tr.useTilia;
export const useComputed = tr.useComputed;
