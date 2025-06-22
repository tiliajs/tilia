export interface GraphSetting {
  title: string;
  seed: number;
  users: number;
  folders: number;
  files: number;
  // Number of random connections from users to folders
  usersFolders: number;
  // Number of random connections from folders to files
  foldersFiles: number;
  // Number of updates before flush
  updates: number;
  // Number of file swapping between folders
  swaps: number;
  // How many times to do batch operations
  steps: number;
}
