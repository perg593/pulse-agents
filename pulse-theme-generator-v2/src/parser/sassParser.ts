import { readFile } from "node:fs/promises";
import path from "node:path";

export interface SassVariable {
  name: string;
  value: string;
  file: string;
  line: number;
  column: number;
}

export interface SassMapEntry {
  key: string;
  value: string;
  line: number;
  column: number;
}

export interface SassMap {
  name: string;
  file: string;
  line: number;
  column: number;
  entries: SassMapEntry[];
}

export interface SassParseResult {
  variables: SassVariable[];
  maps: SassMap[];
}

interface ParserState {
  index: number;
  line: number;
  column: number;
}

const identifierRegex = /[A-Za-z0-9_-]/;

function buildLineIndexMap(source: string): number[] {
  const offsets: number[] = [0];
  for (let i = 0; i < source.length; i++) {
    if (source[i] === "\n") {
      offsets.push(i + 1);
    }
  }
  return offsets;
}

function positionFromIndex(lineOffsets: number[], idx: number): { line: number; column: number } {
  let low = 0;
  let high = lineOffsets.length - 1;
  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    if (lineOffsets[mid] <= idx) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  const line = high + 1;
  const column = idx - lineOffsets[high] + 1;
  return { line, column };
}

function skipWhitespaceAndComments(source: string, state: ParserState): void {
  while (state.index < source.length) {
    const char = source[state.index];
    if (char === " " || char === "\t" || char === "\r" || char === "\n") {
      advancePosition(state, char);
      continue;
    }
    if (char === "/" && source[state.index + 1] === "/") {
      // line comment
      advancePosition(state, "/");
      advancePosition(state, "/");
      while (state.index < source.length && source[state.index] !== "\n") {
        advancePosition(state, source[state.index]);
      }
      continue;
    }
    if (char === "/" && source[state.index + 1] === "*") {
      advancePosition(state, "/");
      advancePosition(state, "*");
      while (state.index < source.length) {
        const current = source[state.index];
        if (current === "*" && source[state.index + 1] === "/") {
          advancePosition(state, "*");
          advancePosition(state, "/");
          break;
        }
        advancePosition(state, current);
      }
      continue;
    }
    break;
  }
}

function advancePosition(state: ParserState, char: string): void {
  state.index += 1;
  if (char === "\n") {
    state.line += 1;
    state.column = 1;
  } else {
    state.column += 1;
  }
}

function readIdentifier(source: string, state: ParserState): string {
  let identifier = "";
  while (state.index < source.length && identifierRegex.test(source[state.index] ?? "")) {
    identifier += source[state.index];
    advancePosition(state, source[state.index]!);
  }
  return identifier;
}

function skipString(source: string, state: ParserState): void {
  const quote = source[state.index];
  if (!quote || (quote !== '"' && quote !== "'")) {
    return;
  }
  advancePosition(state, quote);
  while (state.index < source.length) {
    const char = source[state.index];
    if (char === "\\") {
      advancePosition(state, char);
      if (state.index < source.length) {
        advancePosition(state, source[state.index]!);
      }
      continue;
    }
    advancePosition(state, char);
    if (char === quote) {
      break;
    }
  }
}

function readVariableValue(source: string, state: ParserState): { value: string; endIndex: number } {
  const start = state.index;
  let depth = 0;
  while (state.index < source.length) {
    const char = source[state.index];
    if (char === '"' || char === "'") {
      skipString(source, state);
      continue;
    }
    if (char === "(") {
      depth += 1;
      advancePosition(state, char);
      continue;
    }
    if (char === ")") {
      if (depth > 0) {
        depth -= 1;
      }
      advancePosition(state, char);
      continue;
    }
    if (char === "/" && source[state.index + 1] === "/") {
      // inline comment terminates the value
      break;
    }
    if (char === ";" && depth === 0) {
      break;
    }
    advancePosition(state, char);
  }
  const end = state.index;
  return { value: source.slice(start, end).trim(), endIndex: end };
}

function readMap(source: string, state: ParserState): { content: string } {
  const start = state.index;
  let depth = 0;
  while (state.index < source.length) {
    const char = source[state.index];
    if (char === '"' || char === "'") {
      skipString(source, state);
      continue;
    }
    if (char === "/" && source[state.index + 1] === "/") {
      advancePosition(state, "/");
      advancePosition(state, "/");
      while (state.index < source.length && source[state.index] !== "\n") {
        advancePosition(state, source[state.index]!);
      }
      continue;
    }
    if (char === "/" && source[state.index + 1] === "*") {
      advancePosition(state, "/");
      advancePosition(state, "*");
      while (state.index < source.length) {
        const current = source[state.index];
        if (current === "*" && source[state.index + 1] === "/") {
          advancePosition(state, "*");
          advancePosition(state, "/");
          break;
        }
        advancePosition(state, current);
      }
      continue;
    }
    if (char === "(") {
      depth += 1;
      advancePosition(state, char);
      continue;
    }
    if (char === ")") {
      depth -= 1;
      advancePosition(state, char);
      if (depth === 0) {
        break;
      }
      continue;
    }
    advancePosition(state, char);
  }
  const end = state.index;
  return { content: source.slice(start, end) };
}

function parseMapEntries(
  source: string,
  overallSource: string,
  offset: number,
  lineOffsets: number[],
): SassMapEntry[] {
  const entries: SassMapEntry[] = [];
  let depth = 0;
  let entryStart = 0;
  for (let i = 0; i < source.length; i++) {
    const char = source[i];
    if (char === '"' || char === "'") {
      i = skipStringLiteral(source, i);
      continue;
    }
    if (char === "(") {
      depth += 1;
      continue;
    }
    if (char === ")") {
      if (depth > 0) depth -= 1;
      continue;
    }
    if (char === "," && depth === 0) {
      const entry = source.slice(entryStart, i).trim();
      if (entry.length > 0) {
        const startIndex = findEntryStart(overallSource, offset, entryStart);
        const position = positionFromIndex(lineOffsets, startIndex);
        const { key, value } = splitEntry(entry);
        if (key && value) {
          entries.push({ key, value, line: position.line, column: position.column });
        }
      }
      entryStart = i + 1;
    }
  }
  const lastEntry = source.slice(entryStart).trim();
  if (lastEntry.length > 0) {
    const startIndex = findEntryStart(overallSource, offset, entryStart);
    const position = positionFromIndex(lineOffsets, startIndex);
    const { key, value } = splitEntry(lastEntry);
    if (key && value) {
      entries.push({ key, value, line: position.line, column: position.column });
    }
  }
  return entries;
}

function skipStringLiteral(text: string, start: number): number {
  const quote = text[start];
  let i = start + 1;
  while (i < text.length) {
    const char = text[i];
    if (char === "\\") {
      i += 2;
      continue;
    }
    if (char === quote) {
      return i;
    }
    i += 1;
  }
  return text.length - 1;
}

function findEntryStart(source: string, mapStart: number, entryOffset: number): number {
  return mapStart + entryOffset;
}

function splitEntry(entry: string): { key: string; value: string } {
  let depth = 0;
  for (let i = 0; i < entry.length; i++) {
    const char = entry[i];
    if (char === '"' || char === "'") {
      i = skipStringLiteral(entry, i);
      continue;
    }
    if (char === "(") {
      depth += 1;
      continue;
    }
    if (char === ")") {
      if (depth > 0) depth -= 1;
      continue;
    }
    if (char === ":" && depth === 0) {
      const key = entry.slice(0, i).trim();
      const value = entry.slice(i + 1).trim();
      return { key, value };
    }
  }
  return { key: "", value: "" };
}

export async function parseSassFile(filePath: string): Promise<SassParseResult> {
  const absolute = path.resolve(filePath);
  const content = await readFile(absolute, "utf-8");
  const lineOffsets = buildLineIndexMap(content);
  const state: ParserState = { index: 0, line: 1, column: 1 };
  const variables: SassVariable[] = [];
  const maps: SassMap[] = [];

  while (state.index < content.length) {
    skipWhitespaceAndComments(content, state);
    if (state.index >= content.length) {
      break;
    }
    const current = content[state.index];
    if (current !== "$") {
      advancePosition(state, current);
      continue;
    }

    const varStartIndex = state.index;
    const varLine = state.line;
    const varColumn = state.column;

    advancePosition(state, current);
    const name = readIdentifier(content, state);
    skipWhitespaceAndComments(content, state);
    if (content[state.index] !== ":") {
      continue;
    }
    advancePosition(state, ":");
    skipWhitespaceAndComments(content, state);

    if (content[state.index] === "(") {
      const mapStartIndex = state.index;
      const { content: mapContent } = readMap(content, state);
      // move past ')'
      if (state.index < content.length && content[state.index] === ")") {
        advancePosition(state, ")");
      }
      // consume optional whitespace and semicolon
      skipWhitespaceAndComments(content, state);
      if (content[state.index] === ";") {
        advancePosition(state, ";");
      }
      const entries = parseMapEntries(mapContent.slice(1, -1), content, mapStartIndex + 1, lineOffsets);
      maps.push({
        name,
        file: absolute,
        line: varLine,
        column: varColumn,
        entries,
      });
      continue;
    }

    const { value } = readVariableValue(content, state);
    skipWhitespaceAndComments(content, state);
    if (content[state.index] === ";") {
      advancePosition(state, ";");
    }
    variables.push({
      name,
      value,
      file: absolute,
      line: varLine,
      column: varColumn,
    });
  }

  return { variables, maps };
}
