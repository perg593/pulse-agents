#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..', '..');
const INPUT_CSV = path.join(rootDir, 'theme-generator', 'output', 'examples', 'latest-themes.csv');
const GROUPED_CSV = path.join(rootDir, 'theme-generator', 'output', 'examples', 'latest-themes-groups.csv');
const OUTPUT_DIR = path.join(rootDir, 'preview', 'styles', 'examples', 'generated');
const MANIFEST_PATH = path.join(OUTPUT_DIR, 'themes.json');

function assertFileExists(filePath, label) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${label} not found: ${filePath}`);
  }
}

function parseCsv(text) {
  const rows = [];
  let field = '';
  let row = [];
  let insideQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (insideQuotes) {
      if (char === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          insideQuotes = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"') {
      insideQuotes = true;
      continue;
    }

    if (char === ',') {
      row.push(field);
      field = '';
      continue;
    }

    if (char === '\r') {
      continue;
    }

    if (char === '\n') {
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
      continue;
    }

    field += char;
  }

  if (field !== '' || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  return rows;
}

function slugify(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/['"]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/--+/g, '-')
    .slice(0, 80);
}

function uniqueSlug(base, seen) {
  const fallback = base || `theme-${seen.size + 1}`;
  let candidate = fallback;
  let index = 2;
  while (seen.has(candidate)) {
    candidate = `${fallback}-${index}`;
    index += 1;
  }
  seen.add(candidate);
  return candidate;
}

function cleanOutputDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    return;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  entries.forEach((entry) => {
    if (!entry.isFile()) return;
    if (/\.css$/i.test(entry.name) || entry.name === 'themes.json' || entry.name === 'manifest.json') {
      fs.unlinkSync(path.join(dir, entry.name));
    }
  });
}

function loadCsvData(filePath) {
  assertFileExists(filePath, path.basename(filePath));
  const csvContent = fs.readFileSync(filePath, 'utf8');
  const rows = parseCsv(csvContent);
  if (!rows.length) {
    throw new Error(`CSV appears empty: ${filePath}`);
  }
  const [header, ...dataRows] = rows;
  const headerIndex = header.reduce((acc, column, idx) => {
    const key = String(column || '').trim();
    if (key) acc[key] = idx;
    return acc;
  }, {});
  return { headerIndex, dataRows };
}

function extractThemes(data, seenSlugs) {
  const { headerIndex, dataRows } = data;
  const requiredColumns = ['account', 'identifier', 'theme', 'css'];
  requiredColumns.forEach((column) => {
    if (!(column in headerIndex)) {
      throw new Error(`CSV missing required "${column}" column`);
    }
  });

  return dataRows.reduce((acc, row, idx) => {
    if (!row || row.length === 0) return acc;
    const get = (key) => (headerIndex[key] !== undefined ? row[headerIndex[key]] || '' : '');

    const account = get('account');
    const identifier = get('identifier');
    const themeName = get('theme');
    const css = get('css');
    const themeId = get('theme_id');
    const accountGroup = get('account_group');
    const industry = get('industry');

    if (!css.trim()) {
      console.warn(`Skipping empty CSS at row ${idx + 2}`);
      return acc;
    }

    const slugBase =
      slugify(`${identifier}-${themeName}`) || slugify(themeId) || slugify(themeName) || slugify(account);
    const id = uniqueSlug(slugBase, seenSlugs);

    acc.push({
      id,
      account,
      identifier,
      themeName,
      css,
      themeId,
      accountGroup,
      industry
    });
    return acc;
  }, []);
}

function simplifyPharmaLabel(accountGroup, account, industry) {
  const lowerIndustry = (industry || '').toLowerCase();
  const isPharma = lowerIndustry.includes('pharma') || lowerIndustry.includes('health');
  if (!isPharma) {
    return {
      industry: industry || 'Other',
      group: accountGroup || account || 'Other Accounts',
      account: account || null
    };
  }

  const group = accountGroup || '';
  const accountName = account || '';
  let simplifiedAccount = accountName;

  if (group && accountName.startsWith(group)) {
    simplifiedAccount = accountName.slice(group.length).replace(/^[\\s|:_-]+/, '');
  }

  const drugMatch = simplifiedAccount.match(/['’]?([A-Z][A-Za-z0-9]+)$/);
  if (drugMatch && drugMatch[1]) {
    simplifiedAccount = drugMatch[1];
  }

  simplifiedAccount = simplifiedAccount || accountName || group || 'Pharma';

  return {
    industry: industry || 'Healthcare & Pharma',
    group: group || simplifiedAccount,
    account: simplifiedAccount
  };
}

function mergeThemeData(primary, grouped) {
  const byId = new Map();

  primary.forEach((entry) => {
    const { id, account, identifier, themeName, css, themeId, accountGroup, industry } = entry;
    byId.set(id, {
      id,
      name: themeName || id,
      account: account || null,
      identifier: identifier || null,
      accountGroup: accountGroup || null,
      industry: industry || null,
      themeId: themeId || null,
      css
    });
  });

  grouped.forEach((entry) => {
    const { id, account, identifier, themeName, css, themeId, accountGroup, industry } = entry;
    if (!byId.has(id)) {
      byId.set(id, {
        id,
        name: themeName || id,
        account: account || null,
        identifier: identifier || null,
        accountGroup: accountGroup || null,
        industry: industry || null,
        themeId: themeId || null,
        css
      });
    } else {
      const existing = byId.get(id);
      if (!existing.account && account) existing.account = account;
      if (!existing.identifier && identifier) existing.identifier = identifier;
      if (!existing.name && themeName) existing.name = themeName;
      if (!existing.accountGroup && accountGroup) existing.accountGroup = accountGroup;
      if (!existing.industry && industry) existing.industry = industry;
      if (!existing.themeId && themeId) existing.themeId = themeId;
      if (!existing.css && css) existing.css = css;
    }
  });

  return Array.from(byId.values());
}

function run() {
  assertFileExists(INPUT_CSV, 'Latest themes CSV');
  cleanOutputDir(OUTPUT_DIR);

  const primaryData = loadCsvData(INPUT_CSV);
  const groupedData = fs.existsSync(GROUPED_CSV) ? loadCsvData(GROUPED_CSV) : null;
  const seenSlugs = new Set();

  const primaryThemes = extractThemes(primaryData, seenSlugs);
  const groupedThemes = groupedData ? extractThemes(groupedData, seenSlugs) : [];
  const merged = mergeThemeData(primaryThemes, groupedThemes);

  if (!merged.length) {
    throw new Error('No themes were exported; aborting manifest creation.');
  }

  const themes = merged.map((theme) => {
    const simplified = simplifyPharmaLabel(theme.accountGroup, theme.account, theme.industry);
    const file = `${theme.id}.css`;
    const filePath = path.join(OUTPUT_DIR, file);
    fs.writeFileSync(filePath, `${(theme.css || '').trim()}\n`, 'utf8');
    return {
      id: theme.id,
      name: theme.name || theme.id,
      account: simplified.account || theme.account || null,
      identifier: theme.identifier || null,
      accountGroup: simplified.group || theme.accountGroup || null,
      industry: simplified.industry || theme.industry || null,
      themeId: theme.themeId || null,
      file,
      cssPath: `/preview/styles/examples/generated/${file}`,
      bytes: Buffer.byteLength(theme.css || '', 'utf8')
    };
  });

  const manifest = {
    generatedAt: new Date().toISOString(),
    sourceCsv: path.relative(rootDir, INPUT_CSV),
    groupedCsv: fs.existsSync(GROUPED_CSV) ? path.relative(rootDir, GROUPED_CSV) : null,
    total: themes.length,
    themes
  };

  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2));

  console.log(`Exported ${themes.length} themes to ${OUTPUT_DIR}`);
  console.log(`Manifest written to ${MANIFEST_PATH}`);
}

try {
  run();
} catch (error) {
  console.error(`export-example-themes failed: ${error.message}`);
  process.exit(1);
}
