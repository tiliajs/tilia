import type { Data, Graph } from "@feature/graph";
import type { Random } from "@service/random";
import {
  atom,
  createStore,
  type Atom,
  type Getter,
  type WritableAtom,
} from "jotai";
import { picker, pickerTwo } from "./tilia-graph";

type WAtom<T> = WritableAtom<T, [T], void>;

interface User {
  folders: WAtom<Folder[]>;
  value: Atom<number>;
}

interface Folder {
  files: WAtom<File[]>;
  value: Atom<number>;
}

type File = Atom<number>;

export function jotaiGraph(random: Random): Graph {
  let runGraph: () => { sum: number; rng: number } = () => ({ sum: 0, rng: 0 });
  let toData = () => ({} as Data);

  return {
    library: "jotai",

    setup(settings) {
      const store = createStore();
      const [_count, rng] = random.random(settings.seed);
      const pick = picker(rng);
      const pickTwo = pickerTwo(rng);

      const users: User[] = Array.from({ length: settings.users }).map(() => {
        const folders = watom<Folder[]>([]);
        const mult = 0.8 + 0.4 * rng();
        return {
          folders,
          value: atom((get) => {
            // console.log("J USER ", parseFloat(mult.toFixed(2)));
            const v =
              mult *
              get(folders).reduce((acc, f) => {
                // console.log("       =   ", parseFloat(get(f.value).toFixed(2)));
                return (acc + get(f.value)) % 1000;
              }, 0);
            // console.log("     = ", parseFloat(v.toFixed(2)), "---------");
            return v;
          }),
        };
      });

      const folders = Array.from({ length: settings.folders }).map(() => {
        const files = watom<File[]>([]);
        const mult = 0.8 + 0.4 * rng();
        return {
          files,
          value: atom((get) => {
            // console.log("  J FOLDER ", parseFloat(mult.toFixed(2)));
            return (
              mult *
              get(files).reduce((acc, f) => {
                // console.log("      file ", parseFloat(get(f).toFixed(2)));
                return (acc + get(f)) % 1000;
              }, 0)
            );
          }),
        };
      });

      const files = Array.from({ length: settings.files }).map(() =>
        atom(rng() * 10)
      );

      for (let i = 0; i < settings.usersFolders * settings.users; ++i) {
        const [user, folder] = pickTwo(
          users,
          folders,
          (u) => store.get(u.folders).length === settings.folders,
          (u, f) => !store.get(u.folders).includes(f)
        );

        const list = store.get(user.folders);
        store.set(user.folders, [...list, folder]);
      }

      for (let i = 0; i < settings.foldersFiles * settings.folders; ++i) {
        const [folder, file] = pickTwo(
          folders,
          files,
          (fo) => store.get(fo.files).length === settings.files,
          (u, f) => !store.get(u.files).includes(f)
        );

        const list = store.get(folder.files);
        store.set(folder.files, [...list, file]);
      }

      function sum(get: Getter) {
        let sum = 0;
        for (let i = 0; i < users.length / 2; ++i) {
          sum += get(pick(users).value);
        }
        return sum;
      }

      runGraph = () => {
        for (let i = 0; i < settings.steps; ++i) {
          for (let j = 0; j < settings.swaps; ++j) {
            const f1 = pick(folders).files;
            const f1v = store.get(f1);
            const f2 = pick(folders).files;
            const f2v = store.get(f2);
            const i1 = Math.floor(rng() * f1v.length);
            const i2 = Math.floor(rng() * f2v.length);
            const tmp = f1v[i1];
            // No idea about immutability here.
            f1v[i1] = f2v[i2];
            f2v[i2] = tmp;
            store.set(f1, f1v);
            store.set(f2, f2v);
          }
          for (let j = 0; j < settings.updates; ++j) {
            const f = pick(files);
            store.set(f, rng() * 10);
          }
          // compute sum
          sum(store.get);
        }
        return { sum: sum(store.get), rng: rng() };
      };

      toData = () => {
        return {
          users: users.map((u) => ({
            value: store.get(u.value),
            sum: store
              .get(u.folders)
              .reduce((acc, f) => (acc + store.get(f.value)) % 1000, 0),
            folders: store.get(u.folders).map((f) => store.get(f.value)),
          })),
          folders: folders.map((f) => ({
            value: store.get(f.value),
            sum: store
              .get(f.files)
              .reduce((acc, f) => (acc + store.get(f)) % 1000, 0),
            files: store.get(f.files).map((f) => store.get(f)),
          })),
          files: files.map((f) => store.get(f)),
        };
      };
    },

    run: () => runGraph(),

    toData: () => toData(),
  };
}

// Writeable atom
function watom<T>(value: T): WAtom<T> {
  const a = atom(value);
  return atom(
    (get) => get(a),
    (_, set, v: T) => set(a, v)
  );
}
