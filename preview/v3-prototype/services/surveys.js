import { log } from '../ui/log.js';
import { emit } from '../ui/events.js';

const SHEET_CSV_URL =
  'https://docs.google.com/spreadsheets/d/17k7uKh_TGMNy0hJblfImUGmmbkW_71rDbYlIEfya5Z8/gviz/tq?tqx=out:csv&gid=0';

const FALLBACK_SURVEYS = [
  {
    id: '7990',
    label: 'Cyberhill Partners – Experience Agent Demo',
    identifier: 'PI-81598442',
    backgroundUrl: 'https://www.cyberhillpartners.com'
  }
];

export async function loadSurveys() {
  const records = await loadFromSheet().catch((error) => {
    log('net', 'warn', 'Survey sheet unavailable', { error: String(error) });
    emit({
      type: 'error',
      ts: Date.now(),
      code: 'sheet_off',
      message: 'Survey feed unavailable; using fallback demos.',
      data: { error: String(error) }
    });
    return [];
  });
  if (records.length) {
    log('ui', 'event', `Loaded ${records.length} surveys from sheet`);
    return records;
  }
  log('ui', 'warn', 'Using fallback survey catalog');
  return FALLBACK_SURVEYS;
}

async function loadFromSheet() {
  const response = await fetch(SHEET_CSV_URL, { cache: 'no-cache' });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  const text = await response.text();
  return parseSurveyCsv(text);
}

function parseSurveyCsv(text) {
  const rows = parseCsv(text);
  if (!rows.length) return [];
  const [header, ...dataRows] = rows;
  const index = header.reduce((acc, key, i) => {
    const trimmed = (key || '').trim();
    if (trimmed) acc[trimmed] = i;
    return acc;
  }, {});

  const get = (row, key) => {
    const idx = index[key];
    if (idx === undefined) return '';
    return (row[idx] || '').trim();
  };

  return dataRows
    .map((row) => {
      const surveyId = get(row, 'survey_id');
      if (!surveyId) return null;
      return {
        id: String(surveyId),
        label: buildLabel(get(row, 'survey_name'), get(row, 'account_name')),
        identifier: get(row, 'identifier') || undefined,
        backgroundUrl: get(row, 'url') || undefined
      };
    })
    .filter(Boolean);
}

function buildLabel(name, account) {
  if (name && account) return `${name} — ${account}`;
  return name || account || 'Untitled Agent';
}

function parseCsv(text) {
  const rows = [];
  let current = '';
  let row = [];
  let insideQuotes = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (insideQuotes) {
      if (char === '"') {
        if (text[i + 1] === '"') {
          current += '"';
          i += 1;
        } else {
          insideQuotes = false;
        }
      } else {
        current += char;
      }
      continue;
    }
    if (char === '"') {
      insideQuotes = true;
      continue;
    }
    if (char === ',') {
      row.push(current);
      current = '';
      continue;
    }
    if (char === '\r') continue;
    if (char === '\n') {
      row.push(current);
      rows.push(row);
      row = [];
      current = '';
      continue;
    }
    current += char;
  }
  if (current !== '' || row.length) {
    row.push(current);
    rows.push(row);
  }
  return rows;
}
