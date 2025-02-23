// Generated by ReScript, PLEASE EDIT WITH CARE


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

var trackKey = (Symbol());

var metaKey = (Symbol());

function _meta(p) {
  return Reflect.get(p, metaKey);
}

function _connect(p, notify) {
  var match = Reflect.get(p, metaKey);
  if (match === null || match === undefined) {
    if (match === null) {
      throw new Error("Observed state is not a tilia proxy.");
    }
    throw new Error("Observed state is not a tilia proxy.");
  } else {
    var root = match.root;
    var observer_observing = [];
    var observer = {
      notify: notify,
      observing: observer_observing,
      root: root
    };
    root.observer = observer;
    return observer;
  }
}

function observeKey(observed, key) {
  var w = observed.get(key);
  if (!(w === null || w === undefined)) {
    return w;
  }
  w === null;
  var w$1 = {
    state: "Pristine",
    key: key,
    observed: observed,
    observers: new Set()
  };
  observed.set(key, w$1);
  return w$1;
}

function clear(observer) {
  observer.observing.forEach(function (watchers) {
        if (watchers.state === "Pristine" && watchers.observers.delete(observer) && watchers.observers.size === 0) {
          watchers.state = "Cleared";
          watchers.observed.delete(watchers.key);
          return ;
        }
        
      });
}

function _ready(observer, notifyIfChangedOpt) {
  var notifyIfChanged = notifyIfChangedOpt !== undefined ? notifyIfChangedOpt : true;
  var root = observer.root;
  var o = root.observer;
  if (o === null || o === undefined) {
    o === null;
  } else if (o === observer) {
    root.observer = undefined;
  }
  observer.observing.find(function (w, idx) {
        var match = w.state;
        switch (match) {
          case "Pristine" :
              w.observers.add(observer);
              return false;
          case "Changed" :
              if (notifyIfChanged) {
                clear(observer);
                observer.notify();
                return true;
              }
              break;
          case "Cleared" :
              break;
          
        }
        var w$1 = observeKey(w.observed, w.key);
        w$1.observers.add(observer);
        observer.observing[idx] = w$1;
        return false;
      });
}

function collect(accum, ancestry) {
  ancestry.forEach(function (param) {
        var obs = param.obs;
        if (!accum.has(obs)) {
          accum.add(obs);
          return collect(accum, param.ancestry);
        }
        
      });
}

function notify(observed, key) {
  var watchers = observed.get(key);
  if (watchers === null || watchers === undefined) {
    return ;
  }
  observed.delete(key);
  watchers.state = "Changed";
  watchers.observers.forEach(function (observer) {
        clear(observer);
        observer.notify();
      });
}

function triggerTracking(root, propagate) {
  var triggers = root.triggers;
  if (triggers === null || triggers === undefined) {
    triggers === null;
  } else {
    triggers.add(propagate);
    return ;
  }
  var triggers$1 = new Set();
  triggers$1.add(propagate);
  root.triggers = triggers$1;
  root.flush(function () {
        root.triggers = undefined;
        var observers = new Set();
        collect(observers, triggers$1);
        observers.forEach(function (observed) {
              var watchers = observed.get(trackKey);
              if (watchers === null || watchers === undefined) {
                return ;
              }
              watchers.observers.forEach(function (observer) {
                    observer.notify();
                  });
            });
      });
}

function deleteProxied(proxied, propagate, key) {
  var m = proxied.get(key);
  if (m === null || m === undefined) {
    m === null;
  } else {
    m.propagate.ancestry.delete(propagate);
  }
  proxied.delete(key);
}

function proxify(root, _parent_propagate, _target) {
  while(true) {
    var target = _target;
    var parent_propagate = _parent_propagate;
    var proxied = new Map();
    var observed = new Map();
    var ancestry = new Set();
    ancestry.add(parent_propagate);
    var propagate = {
      obs: observed,
      ancestry: ancestry
    };
    var m = Reflect.get(target, metaKey);
    if (m === null || m === undefined) {
      m === null;
    } else {
      if (m.root === root) {
        m.propagate.ancestry.add(parent_propagate);
        return m;
      }
      _target = m.target;
      _parent_propagate = propagate;
      continue ;
    }
    var meta = ({root, target, observed, proxied, propagate});
    var isArray = Array.isArray(target);
    var proxy = new Proxy(target, {
          set: (function(proxied,observed,propagate){
          return function (extra, extra$1, extra$2) {
            var hadKey = Reflect.has(extra, extra$1);
            var prev = Reflect.get(extra, extra$1);
            if (prev === extra$2) {
              return true;
            } else if (Reflect.set(extra, extra$1, extra$2)) {
              if (object(prev)) {
                deleteProxied(proxied, propagate, extra$1);
              }
              notify(observed, extra$1);
              if (!hadKey) {
                notify(observed, indexKey);
              }
              triggerTracking(root, propagate);
              return true;
            } else {
              return false;
            }
          }
          }(proxied,observed,propagate)),
          deleteProperty: (function(proxied,observed,propagate){
          return function (extra, extra$1) {
            var res = Reflect.deleteProperty(extra, extra$1);
            deleteProxied(proxied, propagate, extra$1);
            notify(observed, extra$1);
            triggerTracking(root, propagate);
            return res;
          }
          }(proxied,observed,propagate)),
          get: (function(proxied,observed,propagate,isArray){
          return function (extra, extra$1) {
            if (extra$1 === metaKey) {
              return meta;
            }
            var v = Reflect.get(extra, extra$1);
            var own = Object.hasOwn(extra, extra$1);
            if (!(v === undefined || own)) {
              return v;
            }
            var o = root.observer;
            if (o === null || o === undefined) {
              o === null;
            } else if (isArray && extra$1 === "length") {
              var w = observeKey(observed, indexKey);
              o.observing.push(w);
            } else {
              var w$1 = observeKey(observed, extra$1);
              o.observing.push(w$1);
            }
            if (!(object(v) && !readonly(extra, extra$1))) {
              return v;
            }
            var m = proxied.get(extra$1);
            if (!(m === null || m === undefined)) {
              return m.proxy;
            }
            m === null;
            var m$1 = proxify(root, propagate, v);
            proxied.set(extra$1, m$1);
            return m$1.proxy;
          }
          }(proxied,observed,propagate,isArray)),
          ownKeys: (function(observed){
          return function (extra) {
            var keys = Reflect.ownKeys(extra);
            var o = root.observer;
            if (o === null || o === undefined) {
              o === null;
            } else {
              var w = observeKey(observed, indexKey);
              o.observing.push(w);
            }
            return keys;
          }
          }(observed))
        });
    meta.proxy = proxy;
    return meta;
  };
}

function timeOutFlush(fn) {
  setTimeout((function () {
          fn();
        }), 0);
}

function make(seed, flushOpt) {
  var flush = flushOpt !== undefined ? flushOpt : timeOutFlush;
  var root = {
    observer: undefined,
    triggers: undefined,
    flush: flush
  };
  var propagate_obs = new Map();
  var propagate_ancestry = new Set();
  var propagate = {
    obs: propagate_obs,
    ancestry: propagate_ancestry
  };
  return proxify(root, propagate, seed).proxy;
}

function observe(p, callback) {
  var notify = function () {
    var o = _connect(p, notify);
    callback(p);
    _ready(o, false);
  };
  notify();
}

function track(p, callback) {
  var match = Reflect.get(p, metaKey);
  if (match === null || match === undefined) {
    if (match === null) {
      throw new Error("Observed state is not a tilia proxy.");
    }
    throw new Error("Observed state is not a tilia proxy.");
  } else {
    var observer_notify = function () {
      callback(p);
    };
    var observer_observing = [];
    var observer_root = match.root;
    var observer = {
      notify: observer_notify,
      observing: observer_observing,
      root: observer_root
    };
    var w = observeKey(match.observed, trackKey);
    w.observers.add(observer);
    observer_observing.push(w);
    return observer;
  }
}

export {
  make ,
  observe ,
  track ,
  clear ,
  _connect ,
  _ready ,
  _meta ,
}
/* indexKey Not a pure module */
