open Tilia
let useTilia: unit => unit

/** 
 * Create useTilia from (_observe, _ready, _clear) set the immutable flag to
 * true if you want to throw exceptions if mutations during the render phase. Be careful that you may have false positives if you use this flag due to React effects being called after other async code.
*/
let makeUseTilia: (tilia, bool) => unit => unit
