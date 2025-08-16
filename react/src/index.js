import { _ctx, _done, _ready, _clear, computed } from "tilia";
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
    return useMemo(() => tilia({ value: computed(fn) }), []).value;
  }

  function leaf(fn) {
    return (p) => {
      const [_, setCount] = useState(0);
      const o = _observe(() => setCount((i) => i + 1));

      useEffect(() => {
        _ready(o, true);
        return () => _clear(o);
      });

      const node = fn(p);
      _done(o);
      return node;
    };
  }
  return { useTilia, useComputed, leaf };
}

const lib = make(_ctx);
export const useTilia = lib.useTilia;
export const useComputed = lib.useComputed;
export const leaf = lib.leaf;
