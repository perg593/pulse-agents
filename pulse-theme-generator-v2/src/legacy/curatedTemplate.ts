import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
// eslint-disable-next-line @typescript-eslint/no-var-requires
const curatedBase = require("../../../theme-generator/templates/curated-base.js").default as string;

export const curatedTemplate = curatedBase;
