export type Preview = {
  key: string;
  title: string;
  value: unknown;
  text?: string;
  pinned?: boolean;
};

export const hover = (current: Preview | undefined, next: Preview): Preview =>
  current?.pinned ? current : next;

export const leave = (current: Preview | undefined): Preview | undefined =>
  current?.pinned ? current : undefined;

export const toggle = (current: Preview | undefined, next: Preview): Preview | undefined =>
  current?.pinned && current.key === next.key ? undefined : { ...next, pinned: true };
