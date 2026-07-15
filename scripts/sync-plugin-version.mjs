import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const pkg = JSON.parse(readFileSync(resolve(root, "package.json"), "utf8"));
const pluginPath = resolve(root, ".claude-plugin/plugin.json");
const plugin = JSON.parse(readFileSync(pluginPath, "utf8"));

if (plugin.version === pkg.version) {
  console.log(`plugin.json already at ${pkg.version}`);
} else {
  plugin.version = pkg.version;
  writeFileSync(pluginPath, JSON.stringify(plugin, null, 2) + "\n");
  console.log(`synced plugin.json -> ${pkg.version}`);
}
