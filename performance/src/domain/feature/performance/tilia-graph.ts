import type { Data, Graph } from "@feature/graph";
import type { Random } from "@service/random";
import { make, type Signal } from "tilia";

interface User {
  folders: Folder[];
  readonly value: number;
}

interface Folder {
  files: File[];
  readonly value: number;
}

type File = Signal<number>;

export function tiliaG(batch: boolean): (random: Random) => Graph {
  return (random) => tiliaGraph(random, batch);
}

export function tiliaGraph(random: Random, isBatch: boolean): Graph {
  let runGraph: () => { sum: number; rng: number } = () => ({ sum: 0, rng: 0 });
  let toData = () => ({} as Data);
  return {
    library: `tilia${isBatch ? " (batch)" : ""}`,

    setup(settings) {
      const { tilia, computed, batch } = make();
      const [_count, rng] = random.random(settings.seed);
      const pick = picker(rng);
      const pickTwo = pickerTwo(rng);

      const users: User[] = Array.from({ length: settings.users }).map(() => {
        const folders: Folder[] = tilia([]);
        const mult = rng();
        return tilia({
          folders,
          value: computed(
            () => mult * folders.reduce((acc, f) => acc + f.value, 0)
          ),
        });
      });

      const folders = Array.from({ length: settings.folders }).map(() => {
        const files: File[] = tilia([]);
        const mult = rng();
        return tilia({
          files,
          value: computed(
            () => mult * files.reduce((acc, f) => acc + f.value, 0)
          ),
        });
      });

      const files = Array.from({ length: settings.files }).map(() =>
        tilia({ value: Math.floor(rng() * 100) })
      );

      for (let i = 0; i < settings.usersFolders * settings.users; ++i) {
        const [user, folder] = pickTwo(
          users,
          folders,
          (u) => u.folders.length === settings.folders,
          (u, f) => !u.folders.includes(f)
        );
        user.folders.push(folder);
      }

      for (let i = 0; i < settings.foldersFiles * settings.folders; ++i) {
        const [folder, file] = pickTwo(
          folders,
          files,
          (fo) => fo.files.length === settings.files,
          (fo, f) => !fo.files.includes(f)
        );
        folder.files.push(file);
      }

      const sum = tilia({
        value: computed(() => users.reduce((acc, u) => acc + u.value, 0)),
      });

      function up() {
        for (let j = 0; j < settings.swaps; ++j) {
          const f1 = pick(folders).files;
          const f2 = pick(folders).files;
          const i1 = Math.floor(rng() * f1.length);
          const i2 = Math.floor(rng() * f2.length);
          const tmp = f1[i1];
          f1[i1] = f2[i2];
          f2[i2] = tmp;
        }
        for (let j = 0; j < settings.updates; ++j) {
          const f = pick(files);
          f.value = Math.floor(rng() * 100);
        }
      }

      if (isBatch) {
        runGraph = () => {
          for (let i = 0; i < settings.steps; ++i) {
            batch(() => up());
          }
          return { sum: sum.value, rng: rng() };
        };
      } else {
        runGraph = () => {
          for (let i = 0; i < settings.steps; ++i) {
            up();
          }
          return { sum: sum.value, rng: rng() };
        };
      }

      toData = () => {
        return {
          users: users.map((u) => ({
            value: u.value,
            sum: u.folders.reduce((acc, f) => acc + f.value, 0),
            folders: u.folders.map((f) => f.value),
          })),
          folders: folders.map((f) => ({
            value: f.value,
            sum: f.files.reduce((acc, f) => acc + f.value, 0),
            files: f.files.map((f) => f.value),
          })),
          files: files.map((f) => f.value),
        };
      };
    },

    run: () => runGraph(),

    toData: () => toData(),
  };
}

// HELPERS

export function picker(
  rng: () => number
): <T>(arr: T[], accept?: (v: T) => boolean) => T {
  return (arr, accept = (_) => true) => {
    if (arr.length === 0) throw new Error("Cannot pick from empty array");
    const idx = Math.floor(rng() * arr.length);
    let i = idx;
    while (true) {
      const v = arr[i];
      if (accept(v)) return v;
      i = (i + 1) % arr.length;
      if (i === idx) {
        throw new Error("Could not pick a value: all rejected");
      }
    }
  };
}

export function pickerTwo(
  rng: () => number
): <T, U>(
  arr1: T[],
  arr2: U[],
  full: (t: T) => boolean,
  accept: (t: T, u: U) => boolean
) => [T, U] {
  return (arr1, arr2, full, accept) => {
    if (arr1.length === 0 || arr2.length === 0) {
      throw new Error("Cannot pick from empty array");
    }

    const startIdx1 = Math.floor(rng() * arr1.length);
    const startIdx2 = Math.floor(rng() * arr2.length);

    for (let offset1 = 0; offset1 < arr1.length; offset1++) {
      const i1 = (startIdx1 + offset1) % arr1.length;
      const v1 = arr1[i1];

      // Quick check: if this item is full, skip to next
      if (full(v1)) {
        continue;
      }

      // Search through arr2 for a compatible pair
      for (let offset2 = 0; offset2 < arr2.length; offset2++) {
        const i2 = (startIdx2 + offset2) % arr2.length;
        const v2 = arr2[i2];

        if (accept(v1, v2)) {
          return [v1, v2];
        }
      }
    }

    throw new Error("Could not pick a value: all rejected");
  };
}
