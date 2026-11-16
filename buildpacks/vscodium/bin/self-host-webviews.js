// Make the VSCodium web server host webview content (used by notebooks,
// markdown preview, etc.) itself instead of loading it from Microsoft's CDN.
//
// VSCodium's product.json points `webviewContentExternalBaseUrlTemplate` at
// https://{{uuid}}.vscode-cdn.net/insider/ef65ac1b.../, a 2022 build of the
// webview host page and service worker. That build is not compatible with the
// current workbench, so resources loaded inside webviews fail (e.g. notebook
// renderers: "Failed to fetch dynamically imported module").
//
// Two patches are applied:
// 1. server-main.js: per request, point the webview endpoint at the server's
//    own static copy of `out/vs/workbench/contrib/webview/browser/pre/`.
// 2. pre/index.html: accept being served from the same origin as the
//    workbench (upstream requires a hash-derived subdomain), and update the
//    CSP hash of the inline script accordingly.
//
// Usage: node self-host-webviews.js <vscodium-server-dir>
"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const serverDir = process.argv[2];
if (!serverDir) {
  console.error("Usage: node self-host-webviews.js <vscodium-server-dir>");
  process.exit(2);
}

function replaceOnce(content, search, replacement, file) {
  const count = content.split(search).length - 1;
  if (count !== 1) {
    throw new Error(`Expected exactly one match in ${file}, found ${count}: ${search}`);
  }
  return content.replace(search, () => replacement);
}

// 1. server-main.js
// In the web client server, `o` reads a request header, `u` is the remote
// authority (host[:port], honouring X-Forwarded-Host/-Port) and `h` is the
// static route (<base-path>/<quality>-<commit>/static).
const serverMain = path.join(serverDir, "out", "server-main.js");
let serverMainContent = fs.readFileSync(serverMain, "utf8");
if (serverMainContent.includes("webviewContentExternalBaseUrlTemplate:`")) {
  console.log("VSCodium already patched to self-host webview content");
  process.exit(0);
}
serverMainContent = replaceOnce(
  serverMainContent,
  'P={embedderIdentifier:"server-distro",',
  'P={embedderIdentifier:"server-distro",' +
    'webviewContentExternalBaseUrlTemplate:' +
    '`${(o("x-forwarded-proto")||"http").split(",")[0].trim()}://${u}${h}/out/vs/workbench/contrib/webview/browser/pre/`,',
  serverMain,
);

// 2. webview pre/index.html
const indexHtml = path.join(
  serverDir, "out", "vs", "workbench", "contrib", "webview", "browser", "pre", "index.html",
);
let indexContent = fs.readFileSync(indexHtml, "utf8");
const hostCheck = "if (hostname === parentOriginHash || hostname.startsWith(parentOriginHash + '.')) {";
indexContent = replaceOnce(
  indexContent,
  hostCheck,
  "if (parentOrigin === location.origin) {\n" +
    "\t\t\t\t\treturn start(parentOrigin);\n" +
    "\t\t\t\t}\n\n" +
    "\t\t\t\t" + hostCheck,
  indexHtml,
);
const scripts = [...indexContent.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)];
if (scripts.length !== 1) {
  throw new Error(`Expected exactly one inline script in ${indexHtml}, found ${scripts.length}`);
}
const scriptHash = crypto.createHash("sha256").update(scripts[0][1], "utf8").digest("base64");
indexContent = replaceOnce(
  indexContent,
  indexContent.match(/script-src 'sha256-[^']+'/)?.[0] ?? "script-src 'sha256-",
  `script-src 'sha256-${scriptHash}'`,
  indexHtml,
);

// Only write once both patches applied cleanly, so a failure leaves the
// server untouched rather than half patched.
fs.writeFileSync(serverMain, serverMainContent);
fs.writeFileSync(indexHtml, indexContent);

console.log("Patched VSCodium to self-host webview content");
