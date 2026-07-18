import test from "node:test";
import assert from "node:assert/strict";
import { queue } from "./queue.mjs";

test("waits for the running task", async () => {
  const order = [];
  let release;
  const waiting = new Promise((resolve) => {
    release = resolve;
  });
  const run = queue();

  const first = run(async () => {
    order.push("first start");
    await waiting;
    order.push("first end");
  });
  const second = run(async () => {
    order.push("second");
  });

  await Promise.resolve();
  assert.deepEqual(order, ["first start"]);

  release();
  await Promise.all([first, second]);
  assert.deepEqual(order, ["first start", "first end", "second"]);
});

test("continues after a failed task", async () => {
  const run = queue();

  await assert.rejects(run(async () => {
    throw new Error("failed");
  }));

  await run(async () => {});
});
