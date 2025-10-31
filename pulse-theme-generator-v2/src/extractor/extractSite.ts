import { chromium, Page } from "playwright";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { BrowserCollectorOptions, BrowserCollectorResult } from "./browserCollector.js";
import { EXTRACTION_SETTINGS } from "../utils/constants.js";

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
  }, limit * EXTRACTION_SETTINGS.URL_DISCOVERY_MULTIPLIER);

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

/**
 * Extracts theme data from a website by navigating to it and collecting CSS variables,
 * computed styles, and logo colors.
 *
 * @param options - Extraction configuration options
 * @param options.url - Target website URL to extract from
 * @param options.maxPages - Maximum number of pages to crawl (default: 1)
 * @param options.scheme - Color scheme preference: "light" or "dark" (default: "light")
 * @param options.timeoutMs - Navigation timeout in milliseconds (default: 45000)
 * @returns Promise resolving to extraction results with pages and any errors encountered
 *
 * @example
 * ```typescript
 * const result = await extractSite({
 *   url: "https://example.com",
 *   maxPages: 3,
 *   scheme: "light"
 * });
 * console.log(`Extracted ${result.pages.length} pages`);
 * ```
 */
export async function extractSite(options: SiteExtractionOptions): Promise<SiteExtractionResult> {
  const pages: PageExtractionResult[] = [];
  const errors: string[] = [];
  let browser: Awaited<ReturnType<typeof chromium.launch>> | null = null;
  let context: Awaited<ReturnType<Awaited<ReturnType<typeof chromium.launch>>["newContext"]>> | null = null;

  try {
    browser = await chromium.launch({
      headless: true,
    });
    context = await browser.newContext({
      javaScriptEnabled: true,
      colorScheme: options.scheme ?? "light",
    });
    const timeout = options.timeoutMs ?? EXTRACTION_SETTINGS.DEFAULT_TIMEOUT_MS;

    const page = await context.newPage();
    let snippet: string;
    try {
      snippet = await loadBrowserSnippet();
    } catch (error) {
      throw new Error(`Failed to load browser snippet: ${(error as Error).message}`);
    }

    try {
      await page.addInitScript({ content: snippet });
      await page.goto(options.url, { waitUntil: "load", timeout });
    } catch (error) {
      throw new Error(`Failed to navigate to ${options.url}: ${(error as Error).message}`);
    }

    const collectorOptions: BrowserCollectorOptions = {
      globalSelectors: DEFAULT_GLOBAL_SELECTORS,
      componentSelectors: DEFAULT_COMPONENT_SELECTORS,
      baseProperties: DEFAULT_BASE_PROPERTIES,
      computedTargets: DEFAULT_COMPUTED_TARGETS,
      scheme: options.scheme,
    };

    let primaryResult: BrowserCollectorResult;
    try {
      primaryResult = await page.evaluate((opts) => {
        return (window as unknown as { PulseThemeExtractor: { collect: (input: BrowserCollectorOptions) => Promise<BrowserCollectorResult> } }).PulseThemeExtractor.collect(opts);
      }, collectorOptions);
    } catch (error) {
      throw new Error(`Failed to extract theme data from page: ${(error as Error).message}`);
    }
    pages.push({ ...primaryResult, targetUrl: page.url() });

    const maxPages = options.maxPages ?? 1;
    if (maxPages > 1) {
      let additionalUrls: string[];
      try {
        additionalUrls = await discoverAdditionalUrls(page, maxPages - 1);
      } catch (error) {
        errors.push(`Failed to discover additional URLs: ${(error as Error).message}`);
        additionalUrls = [];
      }

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
          await extraPage.close().catch((err) => {
            errors.push(`Failed to close page ${url}: ${(err as Error).message}`);
          });
        }
      }
    }
  } catch (error) {
    errors.push(`Extraction failed: ${(error as Error).message}`);
  } finally {
    // Ensure cleanup even if errors occur
    if (context) {
      try {
        await context.close();
      } catch (error) {
        errors.push(`Failed to close browser context: ${(error as Error).message}`);
      }
    }
    if (browser) {
      try {
        await browser.close();
      } catch (error) {
        errors.push(`Failed to close browser: ${(error as Error).message}`);
      }
    }
  }

  return { pages, errors };
}
