/**
 * @file copy-static.js
 * @description Copies all static assets from the `static/` folder into the build output directory `serve/static`,
 *              and ensures the `_redirects` file is copied to the Netlify publish root (`serve/`) for proper 301 redirects.
 *              This supports https://github.com/oaworks/discussion/issues/3238.
 */

const fs = require('fs');
const path = require('path');

/**
 * Recursively copies all files and directories from the source path to the destination path.
 *
 * @param {string} src - The path to the source directory.
 * @param {string} dest - The path to the destination directory.
 */
function copyDir(src, dest) {
  if (!fs.existsSync(src)) {
    console.warn(`Source path does not exist: ${src}`);
    return;
  }

  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      if (fs.existsSync(srcPath)) {
        fs.copyFileSync(srcPath, destPath);
      } else {
        console.warn(`File does not exist: ${srcPath}, skipping.`);
      }
    }
  }
}

// Copy all static assets to build output
copyDir('./static', './serve/static');

/**
 * Copies Netlify’s `_redirects` file to the root of the build output (`serve/`)
 * to enable 301 redirects for retired pages, per https://github.com/oaworks/discussion/issues/3238.
 */
const redirectsSrc = './_redirects';
const redirectsDest = './serve/_redirects';

if (fs.existsSync(redirectsSrc)) {
  fs.copyFileSync(redirectsSrc, redirectsDest);
  console.log('_redirects copied to build output for Netlify.');
} else {
  console.warn('No _redirects file found, skipping.');
}
