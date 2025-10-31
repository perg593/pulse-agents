import { chromium, Page } from "playwright";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { BrowserCollectorOptions, BrowserCollectorResult } from "./browserCollector.js";

export interface SiteExtractionOptions {
  url: string;
  maxPages?: number;
  scheme?: "light" | "dark";
  timeoutMs?: number;
}

export interface PageExtractionResult extends BrowserCollectorResult {
  targetUrl: string;
}

export interface SiteExtractionResult {
  pages: PageExtractionResult[];
  errors: string[];
}

let cachedSnippet: string | null = null;

async function loadBrowserSnippet(): Promise<string> {
  if (cachedSnippet) return cachedSnippet;
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const snippetPath = path.resolve(__dirname, "../../scripts/extract-snippet.js");
  cachedSnippet = await readFile(snippetPath, "utf-8");
  return cachedSnippet;
}

export const DEFAULT_GLOBAL_SELECTORS = [
  ":root",
  "html",
  "body",
  ":root[data-theme]",
  "html[data-theme]",
  "body[data-theme]",
  "html.dark",
  "body.dark",
  ".theme-dark",
  "[data-color-scheme]",
];

const DEFAULT_COMPONENT_SELECTORS = [
  "header",
  "nav",
  "main",
  "footer",
  ".app",
  ".layout",
  ".shell",
  ".container",
  ".card",
  ".panel",
  ".surface",
  ".modal",
  ".dialog",
  ".btn",
  "[role=\"button\"]",
  "a",
  ".primary",
  "input",
  "select",
  "textarea",
  ".form-control",
];

const DEFAULT_BASE_PROPERTIES = [
  "color",
  "background",
  "background-color",
  "font-family",
  "font-size",
  "line-height",
  "border-radius",
  "box-shadow",
  "letter-spacing",
  "padding",
];

const DEFAULT_COMPUTED_TARGETS: BrowserCollectorOptions["computedTargets"] = [
  { selector: "body" },
  { selector: "h1" },
  { selector: "h2" },
  { selector: "h3" },
  { selector: "a" },
  { selector: "button" },
  { selector: ".btn" },
  { selector: ".card" },
  { selector: "input[type=submit]" },
];

async function discoverAdditionalUrls(page: Page, limit: number): Promise<string[]> {
  const anchors = await page.evaluate((max) => {
    const urls = new Set<string>();
    const anchorElements = Array.from(document.querySelectorAll<HTMLAnchorElement>("a[href]"));
    for (const anchor of anchorElements) {
      if (urls.size >= max) break;
      const href = anchor.href;
      if (!href) continue;
      if (href.startsWith("mailto:") || href.startsWith("tel:")) continue;
      urls.add(href);
    }
    return Array.from(urls);
  }, limit * 3);

  const base = new URL(page.url());
  const sameOrigin: string[] = [];
  for (const href of anchors) {
    try {
      const url = new URL(href);
      if (url.origin === base.origin && url.href !== base.href) {
        sameOrigin.push(url.href);
      }
    } catch {
      // ignore malformed URLs
    }
    if (sameOrigin.length >= limit) break;
  }
  return sameOrigin.slice(0, limit);
}

export async function extractSite(options: SiteExtractionOptions): Promise<SiteExtractionResult> {
  const browser = await chromium.launch({
    headless: true,
  });
  const context = await browser.newContext({
    javaScriptEnabled: true,
    colorScheme: options.scheme ?? "light",
  });
  const timeout = options.timeoutMs ?? 45000;
  const pages: PageExtractionResult[] = [];
  const errors: string[] = [];

  try {
    const page = await context.newPage();
    const snippet = await loadBrowserSnippet();
    await page.addInitScript({ content: snippet });
    await page.goto(options.url, { waitUntil: "load", timeout });

    const collectorOptions: BrowserCollectorOptions = {
      globalSelectors: DEFAULT_GLOBAL_SELECTORS,
      componentSelectors: DEFAULT_COMPONENT_SELECTORS,
      baseProperties: DEFAULT_BASE_PROPERTIES,
      computedTargets: DEFAULT_COMPUTED_TARGETS,
      scheme: options.scheme,
    };

    const primaryResult = await page.evaluate((opts) => {
      return (window as unknown as { PulseThemeExtractor: { collect: (input: BrowserCollectorOptions) => Promise<BrowserCollectorResult> } }).PulseThemeExtractor.collect(opts);
    }, collectorOptions);
    pages.push({ ...primaryResult, targetUrl: page.url() });

    const maxPages = options.maxPages ?? 1;
    if (maxPages > 1) {
      const additionalUrls = await discoverAdditionalUrls(page, maxPages - 1);
      for (const url of additionalUrls) {
        const extraPage = await context.newPage();
        try {
          await extraPage.addInitScript({ content: snippet });
          await extraPage.goto(url, { waitUntil: "load", timeout });
          const result = await extraPage.evaluate((opts) => {
            return (window as unknown as { PulseThemeExtractor: { collect: (input: BrowserCollectorOptions) => Promise<BrowserCollectorResult> } }).PulseThemeExtractor.collect(opts);
          }, collectorOptions);
          pages.push({ ...result, targetUrl: extraPage.url() });
        } catch (error) {
          errors.push(`Failed to extract ${url}: ${(error as Error).message}`);
        } finally {
          await extraPage.close();
        }
      }
    }
  } catch (error) {
    errors.push(`Extraction failed: ${(error as Error).message}`);
  } finally {
    await context.close();
    await browser.close();
  }

  return { pages, errors };
}
