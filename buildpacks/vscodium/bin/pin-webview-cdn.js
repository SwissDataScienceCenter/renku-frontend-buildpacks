// Point VSCodium's webview host at a matching build on Microsoft's CDN.
//
// VSCodium's product.json sets `webviewContentExternalBaseUrlTemplate` to
// https://{{uuid}}.vscode-cdn.net/insider/ef65ac1b.../, a fixed old build of the
// webview host page and service worker. Since VS Code 1.118 the workbench is not
// compatible with it: webviews (notebooks, markdown preview, extension panels)
// fail with "Found unexpected service worker version" followed by
// "DataCloneError: A ReadableStream could not be cloned because it was not
// transferred". See https://github.com/VSCodium/vscodium/issues/2927
//
// The CDN also hosts a copy of the webview files for every stable release under
// /stable/<microsoft commit>/. This script rewrites the URL, everywhere it
// appears, to that copy for the release being installed. This is the same fix as
// https://github.com/VSCodium/vscodium/pull/3085, applied to the built release.
//
// Usage: node pin-webview-cdn.js <vscodium-server-dir> <vscodium-version>
"use strict";

const fs = require("fs");
const path = require("path");

const [serverDir, version] = process.argv.slice(2);
if (!serverDir || !version) {
  console.error("Usage: node pin-webview-cdn.js <vscodium-server-dir> <vscodium-version>");
  process.exit(2);
}

// The URL is baked into several bundles, not only product.json.
const cdnPath = /vscode-cdn\.net\/insider\/[0-9a-f]{40}\//g;

function* sourceFiles(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const entryPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== "node_modules") yield* sourceFiles(entryPath);
    } else if (/\.(js|json)$/.test(entry.name)) {
      yield entryPath;
    }
  }
}

async function microsoftCommit() {
  // VSCodium records the Microsoft commit each release is built from.
  const url = `https://raw.githubusercontent.com/VSCodium/vscodium/${version}/upstream/stable.json`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status}`);
  }
  const { commit } = await response.json();
  if (!/^[0-9a-f]{40}$/.test(commit)) {
    throw new Error(`Unexpected commit in ${url}: ${commit}`);
  }
  return commit;
}

async function main() {
  const replacement = `vscode-cdn.net/stable/${await microsoftCommit()}/`;
  let patched = 0;
  for (const file of sourceFiles(serverDir)) {
    const content = fs.readFileSync(file, "utf8");
    if (!cdnPath.test(content)) continue;
    cdnPath.lastIndex = 0;
    fs.writeFileSync(file, content.replace(cdnPath, replacement));
    patched++;
  }
  if (patched === 0) {
    console.log("VSCodium webview CDN url already up to date or not found");
    return;
  }
  console.log(`Pointed ${patched} files at ${replacement}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
