import { homedir } from 'node:os';
import { join } from 'node:path';

export function getDefaultReposPath(): string {
  if (process.platform === 'win32') {
    const appData = process.env.APPDATA ?? join(homedir(), 'AppData', 'Roaming');
    return join(appData, 'payfin-code', 'repos');
  }
  return join(homedir(), '.payfin-code', 'repos');
}
