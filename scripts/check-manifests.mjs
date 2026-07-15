import { readFileSync, existsSync, readdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => readFileSync(resolve(root, p), "utf8");
let failed = false;
const fail = (msg) => {
  console.error(`FAIL: ${msg}`);
  failed = true;
};

// 1. Version sync between package.json and .claude-plugin/plugin.json
const { version: pkgVersion } = JSON.parse(read("package.json"));
const { version: pluginVersion } = JSON.parse(read(".claude-plugin/plugin.json"));
if (pkgVersion !== pluginVersion) {
  fail(`version mismatch: package.json=${pkgVersion} plugin.json=${pluginVersion}`);
} else {
  console.log(`OK version: ${pkgVersion}`);
}

// 2. Promoted-skill lists stay in sync: plugin.json, docs/, top-level README
const promotedBuckets = ["engineering", "productivity"];
const pluginSkills = JSON.parse(read(".claude-plugin/plugin.json"))
  .skills.map((s) => s.replace(/^\.\/skills\//, "").replace(/\/$/, ""))
  .filter((s) => promotedBuckets.some((b) => s.startsWith(b + "/")))
  .sort();

const docsSkills = [];
for (const b of promotedBuckets) {
  const dir = resolve(root, `docs/${b}`);
  if (!existsSync(dir)) continue;
  for (const f of readdirSync(dir)) {
    if (f.endsWith(".md")) docsSkills.push(`${b}/${f.replace(/\.md$/, "")}`);
  }
}
docsSkills.sort();

const readmeSkills = [
  ...new Set(
    [...read("README.md").matchAll(/skills\/(engineering|productivity)\/([a-z-]+)\/SKILL\.md/g)].map(
      (m) => `${m[1]}/${m[2]}`,
    ),
  ),
].sort();

const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);
if (!eq(pluginSkills, docsSkills)) {
  fail(`plugin.json skills != docs/ pages\n  plugin: ${pluginSkills.join(", ")}\n  docs:  ${docsSkills.join(", ")}`);
} else {
  console.log(`OK promoted docs: ${docsSkills.length} skills`);
}
if (!eq(pluginSkills, readmeSkills)) {
  fail(`plugin.json skills != README links\n  plugin:  ${pluginSkills.join(", ")}\n  readme: ${readmeSkills.join(", ")}`);
} else {
  console.log(`OK README links: ${readmeSkills.length} skills`);
}

if (failed) process.exit(1);
console.log("All manifest checks passed.");
