// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Foo from "./Foo.res.mjs";
import * as Tilia from "./Tilia.res.mjs";
import * as React from "react";
import * as Button from "./Button.res.mjs";
import * as Counter from "./Counter.res.mjs";
import * as Caml_option from "rescript/lib/es6/caml_option.js";
import * as JsxRuntime from "react/jsx-runtime";
import * as RescriptReactErrorBoundary from "@rescript/react/src/RescriptReactErrorBoundary.res.mjs";

var t = Tilia.make({
      count: 0,
      total: 0
    });

function App(props) {
  var match = React.useState(function () {
        return true;
      });
  var setShow = match[1];
  var show = match[0];
  var c = Tilia.use(t);
  return JsxRuntime.jsxs(JsxRuntime.Fragment, {
              children: [
                JsxRuntime.jsxs("div", {
                      children: [
                        JsxRuntime.jsx("h1", {
                              children: "Tilia test",
                              className: "text-3xl font-semibold m-4"
                            }),
                        JsxRuntime.jsx(Foo.make, {}),
                        JsxRuntime.jsx("div", {
                              children: JsxRuntime.jsx(Button.make, {
                                    children: Caml_option.some(show ? "Hide" : "Show"),
                                    onClick: (function (param) {
                                        setShow(function (s) {
                                              return !s;
                                            });
                                      })
                                  }),
                              className: "p-4"
                            }),
                        JsxRuntime.jsx(RescriptReactErrorBoundary.make, {
                              children: show ? JsxRuntime.jsx(Counter.make, {
                                      t: t
                                    }) : JsxRuntime.jsx("div", {}),
                              fallback: (function (param) {
                                  return JsxRuntime.jsx("div", {
                                              children: "Error"
                                            });
                                })
                            })
                      ],
                      className: "p-6"
                    }),
                JsxRuntime.jsx("div", {
                      children: JsxRuntime.jsx(Button.make, {
                            children: Caml_option.some(c.total.toString()),
                            onClick: (function (param) {
                                c.total = c.total + 1 | 0;
                              })
                          }),
                      className: "p-4"
                    })
              ]
            });
}

var make = App;

export {
  make ,
}
/* t Not a pure module */
