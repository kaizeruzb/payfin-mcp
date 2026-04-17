import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = parseInt(process.env.PORT ?? '3000', 10);
const INSTALLER_DIR = resolve(__dirname, '..');

const mime = {
  html: 'text/html; charset=utf-8',
  ps1: 'text/plain; charset=utf-8',
  sh: 'text/plain; charset=utf-8',
  css: 'text/css; charset=utf-8',
  js: 'application/javascript; charset=utf-8',
  svg: 'image/svg+xml',
  ico: 'image/x-icon',
};

const ROUTES = {
  '/': { file: join(__dirname, 'index.html'), type: 'html' },
  '/setup.ps1': { file: join(INSTALLER_DIR, 'setup.ps1'), type: 'ps1' },
  '/setup.sh': { file: join(INSTALLER_DIR, 'setup.sh'), type: 'sh' },
  '/health': { inline: 'ok', type: 'html' },
};

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', 'http://localhost');
  const route = ROUTES[url.pathname];

  if (!route) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found. See /');
    return;
  }

  try {
    const body = route.inline ?? await readFile(route.file);
    res.writeHead(200, {
      'Content-Type': mime[route.type] ?? 'text/plain',
      'Cache-Control': 'public, max-age=300',
    });
    res.end(body);
  } catch (e) {
    console.error(`Request error for ${url.pathname}:`, e);
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Internal server error');
  }
});

server.listen(PORT, () => {
  console.log(`payfin-installer listening on :${PORT}`);
});
