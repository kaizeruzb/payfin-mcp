import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = parseInt(process.env.PORT ?? '3000', 10);
const INSTALLER_DIR = resolve(__dirname, '..');
const KB_URL = process.env.KB_URL ?? 'https://practical-generosity-production-cb1c.up.railway.app';

const mime = {
  html: 'text/html; charset=utf-8',
  ps1: 'text/plain; charset=utf-8',
  sh: 'text/plain; charset=utf-8',
  txt: 'text/plain; charset=utf-8',
};

const STATIC_ROUTES = {
  '/': { file: join(__dirname, 'index.html'), type: 'html', auth: true },
  '/setup.ps1': { file: join(INSTALLER_DIR, 'setup.ps1'), type: 'ps1', auth: true },
  '/setup.sh': { file: join(INSTALLER_DIR, 'setup.sh'), type: 'sh', auth: true },
};

const TOKEN_CACHE = new Map();
const TOKEN_TTL_MS = 5 * 60 * 1000;

async function validateToken(token) {
  if (!token || !/^pfk_[a-f0-9]{8,}$/i.test(token)) return false;
  const cached = TOKEN_CACHE.get(token);
  if (cached && Date.now() - cached.ts < TOKEN_TTL_MS) return cached.valid;

  try {
    const res = await fetch(`${KB_URL}/setup/manifest?token=${encodeURIComponent(token)}`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000),
    });
    const valid = res.status === 200;
    TOKEN_CACHE.set(token, { valid, ts: Date.now() });
    return valid;
  } catch {
    return false;
  }
}

function secureHeaders(extra = {}) {
  return {
    'X-Robots-Tag': 'noindex, nofollow, nosnippet, noarchive',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
    ...extra,
  };
}

function unauthorizedResponse(res) {
  res.writeHead(401, secureHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
  res.end(
    'Unauthorized.\n\n' +
    'This endpoint requires a valid PayFin KB token.\n' +
    'Append ?token=pfk_... to the URL.\n' +
    'If you don\'t have a token, contact your administrator.\n'
  );
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', 'http://localhost');

  if (url.pathname === '/health') {
    res.writeHead(200, secureHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
    res.end('ok');
    return;
  }

  if (url.pathname === '/robots.txt') {
    res.writeHead(200, secureHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
    res.end('User-agent: *\nDisallow: /\n');
    return;
  }

  const route = STATIC_ROUTES[url.pathname];
  if (!route) {
    res.writeHead(404, secureHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
    res.end('Not found');
    return;
  }

  if (route.auth) {
    const token = url.searchParams.get('token') ?? '';
    const ok = await validateToken(token);
    if (!ok) {
      unauthorizedResponse(res);
      return;
    }
  }

  try {
    const body = await readFile(route.file);
    res.writeHead(200, secureHeaders({
      'Content-Type': mime[route.type] ?? 'text/plain',
      'Cache-Control': 'private, no-store',
    }));
    res.end(body);
  } catch (e) {
    console.error(`Request error for ${url.pathname}:`, e);
    res.writeHead(500, secureHeaders({ 'Content-Type': 'text/plain; charset=utf-8' }));
    res.end('Internal server error');
  }
});

server.listen(PORT, () => {
  console.log(`payfin-installer listening on :${PORT}`);
});
