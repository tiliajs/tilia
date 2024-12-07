// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Blink from "./Blink.res.mjs";
import * as Tilia from "./Tilia.res.mjs";
import * as React from "react";
import * as Button from "./Button.res.mjs";
import * as Caml_option from "rescript/lib/es6/caml_option.js";
import * as JsxRuntime from "react/jsx-runtime";

function Counter(props) {
  var match = React.useState(function () {
        return 0;
      });
  var setI = match[1];
  var c = Tilia.use(props.t);
  return JsxRuntime.jsx("div", {
              children: JsxRuntime.jsxs(Blink.make, {
                    children: [
                      JsxRuntime.jsx("div", {
                            children: JsxRuntime.jsx(Button.make, {
                                  children: Caml_option.some("count is " + c.count.toString()),
                                  onClick: (function (param) {
                                      c.count = c.count + 10 | 0;
                                    })
                                }),
                            className: "p-4"
                          }),
                      JsxRuntime.jsx("div", {
                            children: JsxRuntime.jsx(Button.make, {
                                  children: Caml_option.some("i is " + match[0].toString()),
                                  onClick: (function (param) {
                                      setI(function (i) {
                                            return i + 1 | 0;
                                          });
                                    })
                                }),
                            className: "p-4"
                          })
                    ]
                  }),
              className: "bg-white p-4 border-teal-600 rounded-md border"
            });
}

var make = Counter;

export {
  make ,
}
/* Blink Not a pure module */