# Tilia Trade-offs

This document records intentional behavior choices in the core runtime.

## Computed Pruning Is Not Default

### Context

Tilia `computed` values are pull-based and cached. A computed is invalidated
when one of its observed dependencies changes.

In branch-switching graphs with memoized selectors, old dependencies can remain
observed longer than expected under current non-pruned default behavior.
In downstream systems that inspect liveness (`_canopy`), this can make an old
branch look live until its observer graph is rebuilt or collected.

### Why Not Prune All The Time

Always pruning would fix the stale-branch liveness case, but it is not the
default because it changes core behavior in ways that are costly and riskier:

1. Higher churn on observer turnover:
   - pruning resets computed internals and forces more rebuilds on later reads
   - frequent attach/detach cycles pay extra recompute and allocation cost

2. More fragile teardown order:
   - eager deep cleanup during detachment is more sensitive to graph rebuild
     timing
   - this area already has lifecycle edge cases where non-pruning detach is
     safer for disposal paths

3. Broader semantic impact:
   - making pruning default would change behavior for every computed chain, not
     only memoized branch-switch selectors
   - existing apps rely on current non-pruned defaults for stable runtime
     characteristics

### Current Decision

- Default `computed` remains non-pruned. Only clearing (removing) an observer prunes
  downstream computed without watchers.
- There is currently no public API to force pruning for `computed`.

### Practical Guidance

- Use default `computed` for general derivations.
- If strict liveness is required make sure to use `_canopy` on the exposed
  object, not on a shared internal object (see how @tilia/query solves this).
