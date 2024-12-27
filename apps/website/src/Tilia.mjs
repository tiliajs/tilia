// Generated by ReScript, PLEASE EDIT WITH CARE

import * as React from "react";
import * as TiliaCore from "./TiliaCore.mjs";

function use(p) {
  var match = React.useState(0);
  var setCount = match[1];
  var o = TiliaCore._connect(p, (function () {
          setCount(function (i) {
                return i + 1 | 0;
              });
        }));
  React.useEffect(function () {
        TiliaCore._ready(o, undefined);
        return (function () {
                  TiliaCore._clear(o);
                });
      });
  return p;
}

var make = TiliaCore.make;

var observe = TiliaCore.observe;

export {
  make ,
  observe ,
  use ,
}
/* react Not a pure module */