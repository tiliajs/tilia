import { describe, expect, it } from "vitest";
import { hover, leave, toggle, type Preview } from "../src/ui/preview";

const first: Preview = { key: "first", title: "First", value: 1 };
const second: Preview = { key: "second", title: "Second", value: 2 };

describe("preview triggers", () => {
  it("previews on hover and clears on leave", () => {
    expect(hover(undefined, first)).toEqual(first);
    expect(leave(first)).toBeUndefined();
  });

  it("pins a preview on click until clicked again", () => {
    const pinned = toggle(first, first);

    expect(pinned).toEqual({ ...first, pinned: true });
    expect(leave(pinned)).toBe(pinned);
    expect(toggle(pinned, first)).toBeUndefined();
  });

  it("keeps a pinned preview during other hovers and switches on click", () => {
    const pinned = { ...first, pinned: true };

    expect(hover(pinned, second)).toBe(pinned);
    expect(toggle(pinned, second)).toEqual({ ...second, pinned: true });
  });
});
