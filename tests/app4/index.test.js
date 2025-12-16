const {observe, signal} = require('tilia');

describe('Tilia CJS', () => {
  it('should support signal and observe', () => {
    const result = {s: 0};
    const [s, set] = signal(4);

    observe(() => {
      result.s = s.value;
    });

    expect(result.s).toBe(4);

    set(5);

    expect(result.s).toBe(5);
  });
});
