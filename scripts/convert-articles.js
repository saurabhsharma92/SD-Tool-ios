#!/usr/bin/env node
//
// convert-articles.js
//
// Converts Markdown articles in articles/ to HTML.
// Handles GitHub-style alerts (> [!NOTE], > [!TIP], etc.)
// and mermaid fenced code blocks.
//
// Usage:  node scripts/convert-articles.js
//

const { marked } = require('marked');
const fs = require('fs');
const path = require('path');

const ARTICLES_DIR = path.join(__dirname, '..', 'articles');

// ---------------------------------------------------------------------------
// Configure marked: custom mermaid code block renderer
// ---------------------------------------------------------------------------

marked.use({
  renderer: {
    code({ text, lang }) {
      if (lang === 'mermaid') {
        return `<pre class="mermaid">\n${text}\n</pre>\n`;
      }
      return false; // fall through to default renderer
    }
  },
  gfm: true,        // GitHub-flavored markdown (tables, strikethrough, etc.)
  breaks: false,     // don't convert single newlines to <br>
});

// ---------------------------------------------------------------------------
// Pre-process: convert GitHub-style alert blockquotes to raw HTML divs
// ---------------------------------------------------------------------------

const ALERT_TYPES = ['NOTE', 'TIP', 'WARNING', 'IMPORTANT'];
const ALERT_RE = new RegExp(
  `^>\\s*\\[!(${ALERT_TYPES.join('|')})\\]\\s*$`, 'i'
);

/**
 * Scans markdown line-by-line. When a blockquote starts with > [!TYPE],
 * extracts the inner content and emits a <div class="type"> block.
 * Marked passes block-level HTML through, and parses markdown inside
 * <div> blocks that have blank-line separators.
 */
function preprocessAlerts(md) {
  const lines = md.split('\n');
  const out = [];
  let i = 0;

  while (i < lines.length) {
    const m = lines[i].match(ALERT_RE);
    if (m) {
      const type = m[1].toLowerCase();
      const content = [];
      i++; // skip the [!TYPE] line

      // Collect continuation lines belonging to this blockquote
      while (i < lines.length) {
        if (lines[i].startsWith('> ')) {
          content.push(lines[i].substring(2));
          i++;
        } else if (lines[i] === '>') {
          content.push('');
          i++;
        } else {
          break;
        }
      }

      // Emit raw HTML div. Blank lines around content let marked parse
      // the inner markdown (bold, lists, code, etc.)
      out.push('');
      out.push(`<div class="${type}">`);
      out.push('');
      out.push(...content);
      out.push('');
      out.push('</div>');
      out.push('');
    } else {
      out.push(lines[i]);
      i++;
    }
  }

  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Extract title from first # heading (strip emoji)
// ---------------------------------------------------------------------------

function extractTitle(md) {
  const m = md.match(/^#\s+(.+)/m);
  if (!m) return 'Article';
  // Strip leading emoji (Unicode emoji ranges)
  return m[1]
    .replace(/[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]\s*/gu, '')
    .trim();
}

// ---------------------------------------------------------------------------
// Convert a single .md file → .html
// ---------------------------------------------------------------------------

function convertFile(mdPath) {
  const md = fs.readFileSync(mdPath, 'utf-8');
  const title = extractTitle(md);
  const preprocessed = preprocessAlerts(md);
  const body = marked.parse(preprocessed);

  const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title}</title>
</head>
<body>

${body}
</body>
</html>`;

  const htmlPath = mdPath.replace(/\.md$/, '.html');
  fs.writeFileSync(htmlPath, html, 'utf-8');
  console.log(`  ✓ ${path.basename(mdPath)} → ${path.basename(htmlPath)}`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const mdFiles = fs.readdirSync(ARTICLES_DIR)
  .filter(f => f.endsWith('.md') && f !== 'index.md')
  .map(f => path.join(ARTICLES_DIR, f));

if (mdFiles.length === 0) {
  console.log('No .md files found in articles/');
  process.exit(0);
}

console.log(`Converting ${mdFiles.length} article(s)...\n`);
mdFiles.forEach(convertFile);
console.log(`\nDone! ${mdFiles.length} file(s) converted.`);
