/* eslint-disable no-restricted-globals */
import { IMAGE_SAMPLING, LOGO_LIMITS, EXTRACTION_SETTINGS } from "../utils/constants.js";

export interface BrowserCollectorOptions {
  globalSelectors: string[];
  componentSelectors: string[];
  baseProperties: string[];
  computedTargets: {
    selector: string;
    properties?: string[];
    limit?: number;
  }[];
  maxCustomPropsPerSelector?: number;
  scheme?: "light" | "dark";
}

export interface CollectedDeclaration {
  selector: string;
  property: string;
  value: string;
  important: boolean;
  source: string | null;
  atRules: string[];
  type: "css-var" | "base";
}

export interface ComputedSample {
  selector: string;
  sampleIndex: number;
  properties: Record<string, string>;
  customProperties: Record<string, string>;
}

export interface LogoColorSample {
  source: string;
  method: "image" | "svg";
  colors: string[];
  alt?: string | null;
}

export interface BrowserCollectorResult {
  pageUrl: string;
  timestamp: string;
  globalDeclarations: CollectedDeclaration[];
  componentDeclarations: CollectedDeclaration[];
  computed: ComputedSample[];
  logos: LogoColorSample[];
  metadata: {
    themeCandidates: Record<string, string | null>;
    scheme?: string;
  };
  errors: string[];
}

interface TraversalContext {
  atRules: string[];
}

/**
 * Collects theme data from the current page by analyzing CSS stylesheets,
 * computed styles, and logo colors.
 *
 * @param options - Collection configuration options
 * @param options.globalSelectors - CSS selectors to treat as global scope (e.g., :root, html, body)
 * @param options.componentSelectors - CSS selectors for component-level extraction
 * @param options.baseProperties - CSS properties to extract (e.g., color, font-family)
 * @param options.computedTargets - Elements to sample computed styles from
 * @param options.maxCustomPropsPerSelector - Maximum CSS custom properties to extract per selector
 * @param options.scheme - Color scheme preference: "light" or "dark"
 * @returns Promise resolving to collected theme data including declarations, computed samples, and logos
 *
 * @example
 * ```typescript
 * const result = await collectThemeData({
 *   globalSelectors: [":root", "html"],
 *   componentSelectors: ["header", ".card"],
 *   baseProperties: ["color", "background-color"],
 *   computedTargets: [{ selector: "body" }],
 *   scheme: "light"
 * });
 * ```
 */
export async function collectThemeData(options: BrowserCollectorOptions): Promise<BrowserCollectorResult> {
  const errors: string[] = [];
  const globalSet = new Set(options.globalSelectors.map((selector) => selector.trim()));
  const componentSet = new Set(options.componentSelectors.map((selector) => selector.trim()));
  const baseProperties = new Set(options.baseProperties);

  const globalDeclarations: CollectedDeclaration[] = [];
  const componentDeclarations: CollectedDeclaration[] = [];

  function pushDeclaration(
    list: CollectedDeclaration[],
    selector: string,
    property: string,
    value: string,
    important: boolean,
    source: string | null,
    atRules: string[],
  ) {
    list.push({
      selector,
      property,
      value,
      important,
      source,
      atRules: atRules.slice(),
      type: property.startsWith("--") ? "css-var" : "base",
    });
  }

  function matchesSelector(target: string, candidate: string): boolean {
    const trimmed = candidate.trim();
    if (trimmed === target) return true;
    if (trimmed.includes(target)) return true;
    return false;
  }

  function handleStyleRule(
    rule: CSSStyleRule,
    source: string | null,
    context: TraversalContext,
  ) {
    const selectors = rule.selectorText.split(",").map((s) => s.trim());
    const matchedGlobals = selectors.filter((sel) => Array.from(globalSet).some((target) => matchesSelector(target, sel)));
    const matchedComponents = selectors.filter((sel) =>
      Array.from(componentSet).some((target) => matchesSelector(target, sel)),
    );

    const captureCustomProperties = (list: CollectedDeclaration[], selectorsToReport: string[]) => {
      if (selectorsToReport.length === 0) {
        return;
      }
      for (const selector of selectorsToReport) {
        for (let i = 0; i < rule.style.length; i++) {
          const property = rule.style[i]!;
          const value = rule.style.getPropertyValue(property);
          const important = rule.style.getPropertyPriority(property) === "important";
          if (property.startsWith("--")) {
            pushDeclaration(list, selector, property, value, important, source, context.atRules);
          } else if (baseProperties.has(property)) {
            pushDeclaration(list, selector, property, value, important, source, context.atRules);
          }
        }
      }
    };

    captureCustomProperties(globalDeclarations, matchedGlobals);
    captureCustomProperties(componentDeclarations, matchedComponents);
  }

  function traverseRules(
    rules: CSSRuleList,
    source: string | null,
    context: TraversalContext,
  ) {
    for (let i = 0; i < rules.length; i++) {
      const rule = rules[i]!;
      if (rule.type === CSSRule.STYLE_RULE) {
        handleStyleRule(rule as CSSStyleRule, source, context);
        continue;
      }
      if (rule.type === CSSRule.MEDIA_RULE) {
        const mediaRule = rule as CSSMediaRule;
        traverseRules(mediaRule.cssRules, source, {
          atRules: [...context.atRules, `@media ${mediaRule.conditionText}`],
        });
        continue;
      }
      if ("cssRules" in rule) {
        const nested = (rule as unknown as CSSGroupingRule).cssRules;
        const name = (rule as CSSConditionRule).conditionText ?? rule.cssText.split("{")[0].trim();
        traverseRules(nested, source, { atRules: [...context.atRules, name] });
      }
    }
  }

  const sheets = Array.from(document.styleSheets);
  for (const sheet of sheets) {
    let rules: CSSRuleList | undefined;
    try {
      rules = sheet.cssRules;
    } catch (error) {
      errors.push(
        `Unable to read stylesheet ${sheet.href ?? "[inline]"}: ${(error as Error).message ?? "unknown error"}`,
      );
    }
    if (!rules) continue;
    traverseRules(rules, sheet.href ?? null, { atRules: [] });
  }

  const computedSamples: ComputedSample[] = [];
  const defaultProperties = ["color", "background-color", "font-family", "font-size", "line-height", "border-radius", "box-shadow", "letter-spacing"];
  const maxCustomProps = options.maxCustomPropsPerSelector ?? EXTRACTION_SETTINGS.MAX_CUSTOM_PROPS_PER_SELECTOR;

  for (const target of options.computedTargets) {
    const nodes = Array.from(document.querySelectorAll<HTMLElement>(target.selector));
    const limit = target.limit ?? 3;
    const properties = target.properties ?? defaultProperties;
    for (let index = 0; index < nodes.length && index < limit; index++) {
      const node = nodes[index]!;
      const style = window.getComputedStyle(node);
      const sampleProps: Record<string, string> = {};
      for (const property of properties) {
        sampleProps[property] = style.getPropertyValue(property).trim();
      }
      const customProps: Record<string, string> = {};
      let customCount = 0;
      for (let i = 0; i < style.length; i++) {
        const property = style[i]!;
        if (!property.startsWith("--")) continue;
        if (customCount >= maxCustomProps) break;
        customProps[property] = style.getPropertyValue(property).trim();
        customCount += 1;
      }
      computedSamples.push({
        selector: target.selector,
        sampleIndex: index,
        properties: sampleProps,
        customProperties: customProps,
      });
    }
  }

  const metadata: BrowserCollectorResult["metadata"] = {
    themeCandidates: {
      documentElementDataset: document.documentElement?.getAttribute("data-theme") ?? null,
      htmlClass: document.documentElement?.className ?? null,
      bodyClass: document.body?.className ?? null,
      bodyDataset: document.body?.getAttribute("data-theme") ?? null,
    },
    scheme: options.scheme,
  };

  function clampChannel(value: number): number {
    return Math.max(0, Math.min(255, Math.round(value)));
  }

  function toHex(r: number, g: number, b: number): string {
    const component = (channel: number) => clampChannel(channel).toString(16).padStart(2, "0");
    return `#${component(r)}${component(g)}${component(b)}`;
  }

  function normalizeCssColor(value: string | null | undefined): string | null {
    if (!value) return null;
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");
    if (!ctx) return null;
    try {
      ctx.fillStyle = value;
      const normalized = ctx.fillStyle;
      if (normalized.startsWith("#")) {
        if (normalized.length === 4) {
          return `#${normalized[1]}${normalized[1]}${normalized[2]}${normalized[2]}${normalized[3]}${normalized[3]}`.toLowerCase();
        }
        return normalized.toLowerCase();
      }
      const rgbMatch = normalized.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*(\d+(?:\.\d+)?))?\)/i);
      if (rgbMatch) {
        const alpha = rgbMatch[4] ? parseFloat(rgbMatch[4]) : 1;
        if (alpha === 0) return null;
        return toHex(parseInt(rgbMatch[1], 10), parseInt(rgbMatch[2], 10), parseInt(rgbMatch[3], 10));
      }
    } catch {
      return null;
    }
    return null;
  }

  async function sampleImageColors(src: string): Promise<string[]> {
    const buckets = new Map<string, { count: number; r: number; g: number; b: number; saturationSum: number }>();
    try {
      const response = await fetch(src, { mode: "cors" });
      if (!response.ok) return [];
      const blob = await response.blob();
      const bitmap = await createImageBitmap(blob);
      const canvas = document.createElement("canvas");
      const ctx = canvas.getContext("2d");
      if (!ctx) return [];
      const width = Math.min(IMAGE_SAMPLING.MAX_SAMPLE_WIDTH, bitmap.width || IMAGE_SAMPLING.MAX_SAMPLE_WIDTH);
      const height = Math.max(1, Math.round((width / Math.max(bitmap.width, 1)) * Math.max(bitmap.height, 1)));
      canvas.width = width;
      canvas.height = height;
      ctx.drawImage(bitmap, 0, 0, width, height);
      const imageData = ctx.getImageData(0, 0, width, height);
      const { data } = imageData;
      for (let i = 0; i < data.length; i += 4) {
        const alpha = data[i + 3] ?? 255;
        if (alpha < 32) continue;
        const r = data[i] ?? 0;
        const g = data[i + 1] ?? 0;
        const b = data[i + 2] ?? 0;
        const key = `${r >> 4}-${g >> 4}-${b >> 4}`;
        let bucket = buckets.get(key);
        if (!bucket) {
          bucket = { count: 0, r: 0, g: 0, b: 0, saturationSum: 0 };
          buckets.set(key, bucket);
        }
        bucket.count += 1;
        bucket.r += r;
        bucket.g += g;
        bucket.b += b;
        const maxChannel = Math.max(r, g, b);
        const minChannel = Math.min(r, g, b);
        const saturation = maxChannel === 0 ? 0 : (maxChannel - minChannel) / maxChannel;
        bucket.saturationSum += saturation;
      }

      const area = width * height;
      const minCount = Math.max(IMAGE_SAMPLING.MIN_COUNT_ABSOLUTE, Math.round(area * IMAGE_SAMPLING.MIN_COUNT_PERCENTAGE));
      const sorted = Array.from(buckets.values())
        .map((bucket) => {
          const avgR = bucket.r / bucket.count;
          const avgG = bucket.g / bucket.count;
          const avgB = bucket.b / bucket.count;
          return {
            hex: toHex(avgR, avgG, avgB).toLowerCase(),
            count: bucket.count,
            saturation: bucket.saturationSum / bucket.count,
          };
        })
        .filter((bucket) => bucket.count >= minCount)
        .sort((a, b) => b.count - a.count);

      const picked: string[] = [];
      for (const candidate of sorted) {
        if (candidate.saturation < IMAGE_SAMPLING.MIN_SATURATION && candidate.hex !== "#000000" && candidate.hex !== "#ffffff") {
          continue;
        }
        if (isDuplicateColor(candidate.hex, picked)) continue;
        picked.push(candidate.hex);
        if (picked.length >= LOGO_LIMITS.MAX_COLORS_PER_LOGO) break;
      }

      if (picked.length === 0 && buckets.size > 0) {
        const largest = Array.from(buckets.values()).reduce(
          (acc, bucket) => (bucket.count > acc.count ? bucket : acc),
          { count: 0, r: 0, g: 0, b: 0, saturationSum: 0 },
        );
        if (largest.count > 0) {
          picked.push(
            toHex(largest.r / largest.count, largest.g / largest.count, largest.b / largest.count).toLowerCase(),
          );
        }
      }

      return picked;
    } catch (error) {
      errors.push(`Failed to sample logo image ${src}: ${(error as Error).message ?? error}`);
      return [];
    }
  }

  function extractSvgColors(svg: SVGElement): string[] {
    const colors = new Set<string>();
    const attributes = ["fill", "stroke", "stop-color", "color"];
    const walker = document.createTreeWalker(svg, NodeFilter.SHOW_ELEMENT);
    while (walker.nextNode()) {
      const element = walker.currentNode as Element;
      attributes.forEach((attr) => {
        const value = element.getAttribute(attr);
        const normalized = normalizeCssColor(value ?? undefined);
        if (normalized) {
          colors.add(normalized);
        }
      });
    }
    return Array.from(colors).slice(0, LOGO_LIMITS.MAX_SVG_COLORS);
  }

  /**
   * Checks if a color is too similar to any color in the collection.
   * Uses optimized Set-based lookup for better performance.
   */
  function isDuplicateColor(candidate: string, collection: string[]): boolean {
    const [r, g, b] = channelValues(candidate);
    // Use a threshold-based check instead of linear search
    for (const existing of collection) {
      const [er, eg, eb] = channelValues(existing);
      const distance = Math.abs(r - er) + Math.abs(g - eg) + Math.abs(b - eb);
      if (distance < IMAGE_SAMPLING.DUPLICATE_THRESHOLD) {
        return true;
      }
    }
    return false;
  }

  function channelValues(hex: string): [number, number, number] {
    const normalized = hex.replace("#", "");
    return [
      parseInt(normalized.slice(0, 2), 16),
      parseInt(normalized.slice(2, 4), 16),
      parseInt(normalized.slice(4, 6), 16),
    ];
  }

  async function extractLogoColors(errorBucket: string[]): Promise<LogoColorSample[]> {
    const results: LogoColorSample[] = [];
    const seen = new Set<string>();
    const imageSelectors = [
      'img[src*="logo"]',
      'img[alt*="logo" i]',
      'img[class*="logo" i]',
      'img[id*="logo" i]',
      'img[data-logo]',
      'img[src*="brand"]',
    ];
    const svgSelectors = [
      'svg[class*="logo" i]',
      'svg[id*="logo" i]',
      'svg[data-logo]',
      '[class*="logo" i] svg',
      '[id*="logo" i] svg',
    ];

    const imageNodes = new Set<HTMLImageElement>();
    imageSelectors.forEach((selector) => {
      document.querySelectorAll<HTMLImageElement>(selector).forEach((node) => imageNodes.add(node));
    });

    const svgNodes = new Set<SVGElement>();
    svgSelectors.forEach((selector) => {
      document.querySelectorAll<SVGElement>(selector).forEach((node) => svgNodes.add(node));
    });

    const maxLogos = LOGO_LIMITS.MAX_LOGOS_PER_PAGE;
    let processed = 0;

    for (const node of imageNodes) {
      if (processed >= maxLogos) break;
      const src = node.currentSrc || node.src;
      if (!src || seen.has(src)) continue;
      seen.add(src);
      const colors = await sampleImageColors(src);
      const filtered = colors.filter((color) => color && !/^#?(?:f{2}){3}$/i.test(color.replace('#', '')));
      if (filtered.length === 0) continue;
      results.push({
        source: src,
        method: "image",
        colors: filtered,
        alt: node.alt || null,
      });
      processed += 1;
    }

    for (const svg of svgNodes) {
      if (processed >= maxLogos) break;
      const key = svg.outerHTML.slice(0, 120);
      if (seen.has(key)) continue;
      seen.add(key);
      try {
        const colors = extractSvgColors(svg).filter(Boolean);
        if (colors.length === 0) continue;
        results.push({
          source: svg.outerHTML.slice(0, 500),
          method: "svg",
          colors,
        });
        processed += 1;
      } catch (error) {
        errorBucket.push(`Failed to analyse logo SVG: ${(error as Error).message ?? error}`);
      }
    }

    return results;
  }

  const logos = await extractLogoColors(errors);

  return {
    pageUrl: location.href,
    timestamp: new Date().toISOString(),
    globalDeclarations,
    componentDeclarations,
    computed: computedSamples,
    logos,
    metadata,
    errors,
  };
}

export type { BrowserCollectorOptions as CollectorOptions };
