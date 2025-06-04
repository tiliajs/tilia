// We cannot export from the React code because it would bundle tilia again. We need to import "tilia".
// export { makeUseTilia, useTilia } from "./TiliaReact.mjs";
import { _ctx } from "tilia";
import { useState, useEffect } from "react";

function makeUseTilia({ _observe, _ready, _clear }) {
  return function () {
    var [_, setCount] = useState(0);
    var o = _observe(() => setCount((i) => i + 1));
    useEffect(() => {
      _ready(o, true);
      return () => _clear(o);
    });
  };
}

const useTilia = makeUseTilia(_ctx);

export { useTilia, makeUseTilia };
