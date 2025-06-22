import type { Data, Graph } from "@feature/graph";
import type { Random } from "@service/random";
import { BehaviorSubject, combineLatest, Observable, of } from "rxjs";
import { map, switchMap } from "rxjs/operators";
import { picker, pickerTwo } from "./tilia-graph";

interface User {
  folders: BehaviorSubject<Folder[]>;
  value: Observable<number>;
}

interface Folder {
  files: BehaviorSubject<File[]>;
  value: Observable<number>;
}

type File = BehaviorSubject<number>;

export function rxjsGraph(random: Random): Graph {
  let runGraph: () => { sum: number; rng: number } = () => ({ sum: 0, rng: 0 });
  let toData = () => ({} as Data);

  return {
    library: "rxjs",

    setup(settings) {
      const [_count, rng] = random.random(settings.seed);
      const pick = picker(rng);
      const pickTwo = pickerTwo(rng);

      const users: User[] = Array.from({ length: settings.users }).map(() => {
        const folders = new BehaviorSubject<Folder[]>([]);
        const mult = 0.8 + 0.4 * rng();
        return {
          folders,
          value: folders.pipe(
            switchMap((folders) => {
              if (folders.length === 0) return of(0);
              return combineLatest(folders.map((f) => f.value)).pipe(
                map(
                  (values) => mult * values.reduce((a, b) => (a + b) % 1000, 0)
                )
              );
            })
          ),
        };
      });

      const folders = Array.from({ length: settings.folders }).map(() => {
        const files = new BehaviorSubject<File[]>([]);
        const mult = 0.8 + 0.4 * rng();
        return {
          files,
          value: files.pipe(
            switchMap((files) => {
              if (files.length === 0) return of(0);
              return combineLatest(files).pipe(
                map(
                  (values) => mult * values.reduce((a, b) => (a + b) % 1000, 0)
                )
              );
            })
          ),
        };
      });

      const files = Array.from({ length: settings.files }).map(
        () => new BehaviorSubject<number>(rng() * 10)
      );

      for (let i = 0; i < settings.usersFolders * settings.users; ++i) {
        const [user, folder] = pickTwo(
          users,
          folders,
          (u) => u.folders.value.length === settings.folders,
          (u, f) => !u.folders.value.includes(f)
        );

        user.folders.next([...user.folders.value, folder]);
      }

      for (let i = 0; i < settings.foldersFiles * settings.folders; ++i) {
        const [folder, file] = pickTwo(
          folders,
          files,
          (u) => u.files.value.length === settings.files,
          (u, f) => !u.files.value.includes(f)
        );

        folder.files.next([...folder.files.value, file]);
      }

      const sum = new BehaviorSubject<number>(0);

      combineLatest(users.map((f) => f.value))
        .pipe(map((values) => values.reduce((a, b) => (a + b) % 1000, 0)))
        .subscribe(sum);

      runGraph = () => {
        for (let i = 0; i < settings.steps; ++i) {
          for (let j = 0; j < settings.swaps; ++j) {
            const f1 = pick(folders).files;
            const f1v = f1.value;
            const f2 = pick(folders).files;
            const f2v = f2.value;
            const i1 = Math.floor(rng() * f1v.length);
            const i2 = Math.floor(rng() * f2v.length);
            const tmp = f1v[i1];
            f1v[i1] = f2v[i2];
            f2v[i2] = tmp;
            f1.next(f1v);
            f2.next(f2v);
          }
          for (let j = 0; j < settings.updates; ++j) {
            const f = pick(files);
            f.next(rng() * 10);
          }
          sum.value;
        }
        return { sum: sum.value, rng: rng() };
      };
    },

    run: () => runGraph(),

    toData: () => toData(),
  };
}
