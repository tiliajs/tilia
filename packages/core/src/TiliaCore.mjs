// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Js_exn from "rescript/lib/es6/js_exn.js";

var object = (function(v) {
  return typeof v === 'object' && v !== null;
});

var indexKey = (Symbol());

var rootKey = (Symbol());

var rawKey = (Symbol());

function _connect(p, notify) {
  var root = Reflect.get(p, rootKey);
  if (root === null || root === undefined) {
    return Js_exn.raiseError("Observed state is not a tilia proxy.");
  }
  var observer_watcher = Symbol("");
  var observer_collector = [];
  var observer = {
    watcher: observer_watcher,
    notify: notify,
    collector: observer_collector,
    root: root
  };
  root.collecting = observer_collector;
  return observer;
}

function _clear(observer) {
  var watcher = observer.watcher;
  if (observer.root.observers.delete(watcher)) {
    observer.collector.forEach(function (param) {
          var key = param[1];
          var observed = param[0];
          var watchers = Reflect.get(observed, key);
          if (watchers === null || watchers === undefined || !(watchers.delete(watcher) && watchers.size === 0)) {
            return ;
          } else {
            Reflect.deleteProperty(observed, key);
            return ;
          }
        });
    return ;
  }
  
}

function _flush(observer) {
  var root = observer.root;
  var watcher = observer.watcher;
  var c = root.collecting;
  if (c !== undefined && c === observer.collector) {
    root.collecting = undefined;
  }
  root.observers.set(watcher, observer);
  observer.collector.forEach(function (extra) {
        var key = extra[1];
        var observed = extra[0];
        var watchers = Reflect.get(observed, key);
        var watchers$1;
        var exit = 0;
        if (watchers === null || watchers === undefined) {
          exit = 1;
        } else {
          watchers$1 = watchers;
        }
        if (exit === 1) {
          var watchers$2 = new Set();
          Reflect.set(observed, key, watchers$2);
          watchers$1 = watchers$2;
        }
        watchers$1.add(watcher);
      });
}

function notify(root, observed, key) {
  var watchers = Reflect.get(observed, key);
  if (watchers === null || watchers === undefined) {
    return ;
  }
  Reflect.deleteProperty(observed, key);
  watchers.forEach(function (watcher) {
        var observer = root.observers.get(watcher);
        if (observer !== undefined) {
          _clear(observer);
          return observer.notify();
        }
        
      });
}

function proxify(root, _target) {
  while(true) {
    var target = _target;
    var observed = {};
    var proxied = {};
    var r = Reflect.get(target, rootKey);
    if (r === null || r === undefined) {
      r === null;
    } else {
      if (r === root) {
        return target;
      }
      _target = Reflect.get(target, rawKey);
      continue ;
    }
    return new Proxy(target, {
                set: (function(observed,proxied){
                return function (extra, extra$1, extra$2) {
                  var hadKey = Reflect.has(extra, extra$1);
                  var prev = Reflect.get(extra, extra$1);
                  if (prev === extra$2) {
                    return true;
                  } else if (Reflect.set(extra, extra$1, extra$2)) {
                    if (object(prev)) {
                      Reflect.deleteProperty(proxied, extra$1);
                    }
                    notify(root, observed, extra$1);
                    if (!hadKey) {
                      notify(root, observed, indexKey);
                    }
                    return true;
                  } else {
                    return false;
                  }
                }
                }(observed,proxied)),
                get: (function(target,observed,proxied){
                return function (extra, extra$1) {
                  var isArray = Array.isArray(target);
                  if (extra$1 === rootKey) {
                    return root;
                  }
                  if (extra$1 === rawKey) {
                    return target;
                  }
                  var c = root.collecting;
                  if (c !== undefined) {
                    if (isArray && extra$1 === "length") {
                      c.push([
                            observed,
                            indexKey
                          ]);
                    } else {
                      c.push([
                            observed,
                            extra$1
                          ]);
                    }
                  }
                  var v = Reflect.get(extra, extra$1);
                  if (!object(v)) {
                    return v;
                  }
                  var p = Reflect.get(proxied, extra$1);
                  if (!(p === null || p === undefined)) {
                    return p;
                  }
                  p === null;
                  var p$1 = proxify(root, v);
                  Reflect.set(proxied, extra$1, p$1);
                  return p$1;
                }
                }(target,observed,proxied)),
                ownKeys: (function(observed){
                return function (extra) {
                  var c = root.collecting;
                  if (c !== undefined) {
                    c.push([
                          observed,
                          indexKey
                        ]);
                  }
                  return Reflect.ownKeys(extra);
                }
                }(observed))
              });
  };
}

function make(seed) {
  var root = {
    collecting: undefined,
    observers: new Map()
  };
  return proxify(root, seed);
}

function observe(p, callback) {
  var notify = function () {
    var o = _connect(p, notify);
    callback(p);
    _flush(o);
  };
  notify();
}

export {
  make ,
  observe ,
  _connect ,
  _flush ,
  _clear ,
}
/* indexKey Not a pure module */
