import { useState, useEffect } from "react";
import { _observe, _ready, _clear } from "tilia";

// We cannot use the built version in TiliaReact because
// even if the global context is shared, the synbols are not.
// I do not know how to ensure that rescript uses the JS version.

function makeUseTilia(_observe, _ready, _clear) {
  return function () {
    var [_, setCount] = useState(0);
    var o = _observe(() => setCount((i) => i + 1));
    useEffect(() => {
      _ready(o, true);
      return () => _clear(o);
    });
  };
}

const useTilia = makeUseTilia(_observe, _ready, _clear);

export { useTilia, makeUseTilia };
