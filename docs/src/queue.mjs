export function queue() {
  let pending = Promise.resolve();

  return (task) => {
    const next = pending.then(task);
    pending = next.catch(() => {});
    return next;
  };
}
