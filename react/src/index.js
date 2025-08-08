import { _ctx, _ready, _clear, computed } from "tilia";
import { useMemo, useState, useEffect } from "react";

export function make({ _observe, tilia }) {
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

const lib = make(_ctx);
export const useTilia = lib.useTilia;
export const useComputed = lib.useComputed;
