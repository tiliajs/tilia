// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Tilia from "./Tilia.mjs";
import * as JsxRuntime from "react/jsx-runtime";

var x = Tilia.make({
      foo: "bar"
    });

function Foo(props) {
  var x$1 = Tilia.use(x);
  console.log("Foo render");
  return JsxRuntime.jsx("div", {
              children: x$1.foo,
              onClick: (function (param) {
                  x$1.foo = "C " + x$1.foo;
                })
            });
}

var make = Foo;

export {
  x ,
  make ,
}
/* x Not a pure module */