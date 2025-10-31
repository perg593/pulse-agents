#!/usr/bin/env node
// Converts demo survey configuration CSV into a JSON structure used by the preview app.

const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '../..');
const csvPath = path.join(rootDir, 'preview', 'demo-accounts-surveys-css.csv');
const outPath = path.join(rootDir, 'preview', 'app', 'data', 'demo-surveys.json');

function parseCsv(content) {
  const rows = [];
  let field = '';
  let row = [];
  let inQuotes = false;

  const pushField = () => {
    row.push(field);
    field = '';
  };

  const pushRow = () => {
    if (row.length === 0 || (row.length === 1 && row[0] === '')) {
      row = [];
      return;
    }
    rows.push(row);
    row = [];
  };

  for (let i = 0; i < content.length; i += 1) {
    const char = content[i];
    const next = content[i + 1];

    if (inQuotes) {
      if (char === '"') {
        if (next === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"') {
      inQuotes = true;
      continue;
    }

    if (char === ',') {
      pushField();
      continue;
    }

    if (char === '\n' || char === '\r') {
      pushField();
      if (char === '\r' && next === '\n') {
        i += 1;
      }
      pushRow();
      continue;
    }

    field += char;
  }

  if (field.length > 0 || row.length > 0) {
    pushField();
    pushRow();
  }

  return rows;
}

function camelCase(value) {
  return value
    .replace(/[^a-zA-Z0-9]+(.)/g, (_, chr) => chr.toUpperCase())
    .replace(/^[A-Z]/, (chr) => chr.toLowerCase());
}

function normalizeHeader(name) {
  return camelCase(name.trim().replace(/"/g, ''));
}

function normalizeRow(headers, values) {
  const result = {};
  headers.forEach((header, index) => {
    const key = normalizeHeader(header);
    const raw = values[index] ?? '';
    result[key] = raw;
  });

  const intFields = ['surveyId', 'accountId'];
  intFields.forEach((field) => {
    if (result[field]) {
      const parsed = Number.parseInt(result[field], 10);
      if (!Number.isNaN(parsed)) {
        result[field] = parsed;
      }
    }
  });

  result.surveyCss = result.surveyCss?.trim() ?? '';
  result.themeCss = result.themeCss?.trim() ?? '';
  if (typeof result.url === 'string') {
    result.url = result.url.trim().replace(/\.+$/, '');
    if (result.url && !/^https?:\/\//i.test(result.url) && !result.url.startsWith('/')) {
      result.url = `/${result.url.replace(/^\/+/, '')}`;
    }
  }

  return result;
}

function build() {
  if (!fs.existsSync(csvPath)) {
    throw new Error(`CSV file not found: ${csvPath}`);
  }

  const raw = fs.readFileSync(csvPath, 'utf8');
  const rows = parseCsv(raw);
  if (rows.length === 0) {
    fs.writeFileSync(outPath, '[]\n');
    return;
  }

  const [headers, ...dataRows] = rows;
  const normalizedHeaders = headers.map(normalizeHeader);
  const records = dataRows.map((values) => normalizeRow(normalizedHeaders, values));

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(records, null, 2));
  console.log(`Wrote ${outPath}`);
}

try {
  build();
} catch (error) {
  console.error(error.message || error);
  process.exit(1);
}
