// Generated by ReScript, PLEASE EDIT WITH CARE


if (globalThis["@tilia/core"] === "Loaded") {
  throw new Error("@tilia/core already loaded")
}
globalThis["@tilia/core"] = "Loaded"
;

var object = (function(v) {
  return typeof v === 'object' && v !== null;
});

function readonly(o, k) {
  var d = Object.getOwnPropertyDescriptor(o, k);
  if (d === null || d === undefined) {
    return false;
  } else {
    return d.writable === false;
  }
}

var indexKey = (Symbol());

var rootKey = (Symbol());

var rawKey = (Symbol());

var deadKey = (Symbol());

function _connect(p, notify) {
  var root = Reflect.get(p, rootKey);
  if (root === null || root === undefined) {
    if (root === null) {
      throw new Error("Observed state is not a tilia proxy.");
    }
    throw new Error("Observed state is not a tilia proxy.");
  } else {
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
}

function setForKey(observed, key) {
  var watchers = observed.get(key);
  if (!(watchers === null || watchers === undefined)) {
    return watchers;
  }
  watchers === null;
  var watchers$1 = new Set();
  observed.set(key, watchers$1);
  return watchers$1;
}

function _clear(observer) {
  var watcher = observer.watcher;
  if (observer.root.observers.delete(watcher)) {
    observer.collector.forEach(function (param) {
          var watchers = param[0].get(param[1]);
          if (watchers === null || watchers === undefined) {
            return ;
          } else {
            watchers.delete(watcher);
            return ;
          }
        });
    return ;
  }
  
}

function _flush(observer, notifyIfChangedOpt) {
  var notifyIfChanged = notifyIfChangedOpt !== undefined ? notifyIfChangedOpt : true;
  var root = observer.root;
  var watcher = observer.watcher;
  var c = root.collecting;
  if (c !== undefined && c === observer.collector) {
    root.collecting = undefined;
  }
  var notified = {
    done: false
  };
  root.observers.set(watcher, observer);
  observer.collector.forEach(function (param) {
        if (notified.done) {
          return ;
        }
        var watchers = param[2];
        if (watchers.has(deadKey)) {
          var key = param[1];
          var observed = param[0];
          if (notifyIfChanged) {
            notified.done = true;
            _clear(observer);
            return observer.notify();
          }
          var watchers$1 = setForKey(observed, key);
          watchers$1.add(watcher);
          observer.collector.push([
                observed,
                key,
                watchers$1
              ]);
          return ;
        }
        watchers.add(watcher);
      });
}

function notify(root, observed, key) {
  var watchers = observed.get(key);
  if (watchers === null || watchers === undefined) {
    return ;
  }
  observed.delete(key);
  watchers.forEach(function (watcher) {
        var observer = root.observers.get(watcher);
        if (observer !== undefined) {
          _clear(observer);
          return observer.notify();
        }
        
      });
  watchers.add(deadKey);
}

function proxify(root, _target) {
  while(true) {
    var target = _target;
    var observed = new Map();
    var proxied = new Map();
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
                      proxied.delete(extra$1);
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
                deleteProperty: (function(observed,proxied){
                return function (extra, extra$1) {
                  var res = Reflect.deleteProperty(extra, extra$1);
                  proxied.delete(extra$1);
                  notify(root, observed, extra$1);
                  return res;
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
                  var v = Reflect.get(extra, extra$1);
                  var own = Object.hasOwn(extra, extra$1);
                  if (!(v === undefined || own)) {
                    return v;
                  }
                  var c = root.collecting;
                  if (c !== undefined) {
                    if (isArray && extra$1 === "length") {
                      c.push([
                            observed,
                            indexKey,
                            setForKey(observed, indexKey)
                          ]);
                    } else {
                      c.push([
                            observed,
                            extra$1,
                            setForKey(observed, extra$1)
                          ]);
                    }
                  }
                  if (!(object(v) && !readonly(extra, extra$1))) {
                    return v;
                  }
                  var p = proxied.get(extra$1);
                  if (!(p === null || p === undefined)) {
                    return p;
                  }
                  p === null;
                  var p$1 = proxify(root, v);
                  proxied.set(extra$1, p$1);
                  return p$1;
                }
                }(target,observed,proxied)),
                ownKeys: (function(observed){
                return function (extra) {
                  var keys = Reflect.ownKeys(extra);
                  var c = root.collecting;
                  if (c !== undefined) {
                    c.push([
                          observed,
                          indexKey,
                          setForKey(observed, indexKey)
                        ]);
                  }
                  return keys;
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
    _flush(o, false);
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
/*  Not a pure module */
