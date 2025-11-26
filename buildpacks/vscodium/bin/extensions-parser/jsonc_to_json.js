import { parse } from "jsonc-parser";
import { error, log } from "node:console";
import { readFileSync } from "node:fs";
import { argv, exit } from "node:process";
const args = argv.slice(2);
const jsoncFile = args.at(0);
if (jsoncFile == null) {
  error("jsonc file required");
  exit(1);
}
const jsoncRaw = readFileSync(args[0]).toString("utf-8");
const contents = parse(jsoncRaw);
log(JSON.stringify(contents));
