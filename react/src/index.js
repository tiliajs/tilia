import { _ctx } from "tilia";
import { useState, useEffect } from "react";

function makeUseTilia({ _observe, _ready, _clear }, immutable) {
  return function () {
    var [_, setCount] = useState(0);
    var o = _observe(() => setCount((i) => i + 1), immutable);
    useEffect(() => {
      _ready(o, true);
      return () => _clear(o);
    });
  };
}

const useTilia = makeUseTilia(_ctx, false);

export { useTilia, makeUseTilia };
