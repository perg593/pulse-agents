import { readFileSync } from "node:fs";
import path from "node:path";

export interface ColorDefaultEntry {
  name: string;
  value: string;
  comment: string | null;
}

export interface ColorDefaultGroup {
  base: string;
  entries: ColorDefaultEntry[];
  comments: string[];
}

function normalizeValue(value: string): string {
  const cleaned = value.split("//")[0]?.trim() ?? "";
  return cleaned.replace(/;$/, "").trim();
}

function baseName(name: string): string {
  if (name.startsWith("color-")) {
    const parts = name.split("-");
    if (parts.length >= 2) {
      return `${parts[0]}-${parts[1]}`;
    }
  }
  return name;
}

export function loadColorDefaults(sassPath: string): ColorDefaultGroup[] {
  const resolved = path.resolve(sassPath);
  const content = readFileSync(resolved, "utf-8");
  const lines = content.split(/\r?\n/);

  const groups = new Map<string, ColorDefaultGroup>();
  const groupComments = new Map<string, Set<string>>();

  let lastComment: string | null = null;
  for (const line of lines) {
    const trimmed = line.trim();
    if (/^\/\/\s*-{2,}/.test(trimmed)) {
      break;
    }
    if (trimmed.startsWith("//")) {
      lastComment = trimmed.replace(/^\/\//, "").trim();
      continue;
    }
    const match = trimmed.match(/^\$(color-[\w-]+):\s*([^;]+);/);
    if (!match) {
      if (trimmed.length === 0) {
        lastComment = null;
      }
      continue;
    }
    const name = match[1];
    const value = normalizeValue(match[2]);
    const base = baseName(name);

    if (!groups.has(base)) {
      groups.set(base, { base, entries: [], comments: [] });
      groupComments.set(base, new Set<string>());
    }
    const group = groups.get(base)!;
    group.entries.push({
      name,
      value,
      comment: lastComment,
    });
    if (lastComment) {
      groupComments.get(base)!.add(lastComment);
    }
    lastComment = null;
  }

  return Array.from(groups.values())
    .map((group) => ({
      ...group,
      comments: Array.from(groupComments.get(group.base) ?? []),
    }))
    .sort((a, b) => a.base.localeCompare(b.base, undefined, { numeric: true }));
}
