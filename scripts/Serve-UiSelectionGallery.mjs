// Serve only named public handbooks and curated screenshots, never workspace files or credentials.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = fs.realpathSync(path.resolve('docs/05-ui/style-selection-20261011'));
const port = 5193;
const mime = { '.html': 'text/html; charset=utf-8', '.png': 'image/png', '.json': 'application/json; charset=utf-8', '.md': 'text/markdown; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.webm': 'video/webm' };
const handbookFiles = /^(index\.html|manual\.html|manual\.md|README\.md|catalog\.json|demo-access\.json|evidence-(phase1|ui|product|global|bubble-honor)\.md|evidence-bubble-honor\.json|library-contact\.html|skill-contact\.html|screenshots\/[AS]\d{2}\.png|library-contact\.png|skill-contact\.png|concept\/(index\.html|app\.css|refinements\.css|app\.js|interaction\.webm|(?:desktop|mobile)-(?:discover|room|growth|organizer|dark|detail)\.png))$/;

// Each gallery permits only its manifest-named PNGs and two public index files.
// Real-path checks also prevent a renamed symlink from exposing another directory.
const galleries = new Map();
for (const [name, manifestName, entriesKey] of [
  ['global-product-20261011-v3', 'screenshots.json', 'images'],
  ['world-honor-display-20261011', 'manifest.json', 'files']
]) {
  const galleryRoot = fs.realpathSync(path.resolve('docs/05-ui', name));
  const manifest = JSON.parse(fs.readFileSync(path.join(galleryRoot, manifestName), 'utf8'));
  const files = new Set(['README.md', manifestName]);
  for (const item of manifest[entriesKey]) {
    if (/^[a-zA-Z0-9_-]+\.png$/.test(item.file)) files.add(item.file);
  }
  galleries.set(name, { root: galleryRoot, files });
}

function publicTarget(relative) {
  if (handbookFiles.test(relative)) return { root, target: path.join(root, relative) };
  const segments = relative.split('/');
  if (segments.length !== 2) return null;
  const gallery = galleries.get(segments[0]);
  if (!gallery || !gallery.files.has(segments[1])) return null;
  return { root: gallery.root, target: path.join(gallery.root, segments[1]) };
}

http.createServer((req, res) => {
  try {
    if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405); return res.end(); }
    const raw = decodeURIComponent((req.url || '/').split('?')[0]);
    if (raw.includes('..') || raw.includes('\\') || raw.includes('\0')) { res.writeHead(404); return res.end(); }
    const relative = raw === '/' ? 'index.html' : raw.slice(1);
    const selected = publicTarget(relative);
    if (!selected || !fs.existsSync(selected.target) || !fs.realpathSync(selected.target).startsWith(selected.root + path.sep)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, {
      'Content-Type': mime[path.extname(selected.target)] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; frame-ancestors 'self'"
    });
    if (req.method === 'HEAD') return res.end();
    fs.createReadStream(selected.target).pipe(res);
  } catch { res.writeHead(404); res.end(); }
}).listen(port, '127.0.0.1', () => console.log('UI selection gallery ready at http://127.0.0.1:5193; public artifacts only.'));
