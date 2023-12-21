// copy-static.js
const fs = require('fs');
const path = require('path');

function copyDir(src, dest) {
  if (!fs.existsSync(src)) {
      console.warn(`Source path does not exist: ${src}`);
      return;
  }

  fs.mkdirSync(dest, { recursive: true });
  let entries = fs.readdirSync(src, { withFileTypes: true });

  for (let entry of entries) {
      let srcPath = path.join(src, entry.name);
      let destPath = path.join(dest, entry.name);

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

copyDir('./static', './serve/static');
