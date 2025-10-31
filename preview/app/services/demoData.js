import { fetchJson, fetchText } from './http.js';

const AGENT_CSV_URL = '/preview/data/PulseAgentDemoSurveys.csv';
const DEMO_DATA_URL = '/preview/app/data/demo-surveys.json';

export async function loadDemoSurveys() {
  const csvRecords = await loadAgentCsv().catch(() => null);
  if (Array.isArray(csvRecords) && csvRecords.length > 0) {
    return filterEnabled(csvRecords);
  }

  const data = await fetchJson(DEMO_DATA_URL).catch(() => []);
  return Array.isArray(data) ? filterEnabled(data) : [];
}

export function groupByAccount(records) {
  return records.reduce((acc, record) => {
    const key = record.identifier || record.accountName || 'unknown';
    if (!acc[key]) {
      acc[key] = [];
    }
    acc[key].push(record);
    return acc;
  }, {});
}

async function loadAgentCsv() {
  const raw = await fetchText(AGENT_CSV_URL).catch(() => null);
  if (!raw) return null;

  const rows = parseCsv(raw);
  if (!rows || rows.length === 0) return [];

  const [header, ...dataRows] = rows;
  return dataRows
    .filter((row) => row.some((cell) => cell !== ''))
    .map((row) => buildRecord(header, row));
}

function filterEnabled(records) {
  return records.filter((record) => {
    if (!record || typeof record !== 'object') return false;
    if (!Object.prototype.hasOwnProperty.call(record, 'enabled')) return true;
    const value = record.enabled;
    if (typeof value === 'boolean') return value;
    if (value === undefined || value === null) return true;
    return /^yes$/i.test(String(value).trim());
  });
}

function buildRecord(header, row) {
  const raw = {};
  header.forEach((key, index) => {
    raw[key] = row[index] !== undefined ? row[index] : '';
  });

  return {
    accountName: raw.account_name || '',
    surveyName: raw.survey_name || '',
    identifier: raw.identifier || '',
    surveyId: toNumber(raw.survey_id),
    accountId: toNumber(raw.account_id),
    surveyStatus: normalizeString(raw.survey_status),
    surveyStatusName: raw.survey_status_name || '',
    surveyType: normalizeString(raw.survey_type),
    surveyTypeName: raw.survey_type_name || '',
    inlineTargetSelector: normalizeNullable(raw.inline_target_selector),
    surveyCss: normalizeNullable(raw.survey_css, ''),
    themeId: normalizeString(raw.theme_id),
    theme: raw.theme || '',
    themeCss: normalizeNullable(raw.theme_css, ''),
    surveyTags: raw.survey_tags || '',
    surveyTagAgent: toBoolean(raw.survey_tag_agent),
    enabled: parseEnabled(raw.enabled)
  };
}

function normalizeString(value) {
  if (value === undefined || value === null) return '';
  return String(value);
}

function normalizeNullable(value, fallback = null) {
  if (value === undefined || value === null) return fallback;
  const trimmed = String(value).trim();
  if (!trimmed || /^null$/i.test(trimmed)) return fallback;
  return value;
}

function toNumber(value) {
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
}

function toBoolean(value) {
  if (typeof value === 'boolean') return value;
  if (value === undefined || value === null) return false;
  return /^true$/i.test(String(value).trim());
}

function parseEnabled(value) {
  if (value === undefined || value === null || value === '') return true;
  if (typeof value === 'boolean') return value;
  return /^yes$/i.test(String(value).trim());
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

    if (char === '\r') {
      continue;
    }

    if (char === '\n') {
      row.push(current);
      rows.push(row);
      row = [];
      current = '';
      continue;
    }

    current += char;
  }

  if (current !== '' || row.length > 0) {
    row.push(current);
    rows.push(row);
  }

  return rows;
}
