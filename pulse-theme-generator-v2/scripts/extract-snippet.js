(() => {
  const DEFAULT_OPTIONS = {
    globalSelectors: [
      ":root",
      "html",
      "body",
      ":root[data-theme]",
      "html[data-theme]",
      "body[data-theme]",
      "html.dark",
      "body.dark",
      ".theme-dark",
      "[data-color-scheme]"
    ],
    componentSelectors: [
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
      ".form-control"
    ],
    baseProperties: [
      "color",
      "background",
      "background-color",
      "font-family",
      "font-size",
      "line-height",
      "border-radius",
      "box-shadow",
      "letter-spacing",
      "padding"
    ],
    computedTargets: [
      { selector: "body" },
      { selector: "h1" },
      { selector: "h2" },
      { selector: "a" },
      { selector: "button" },
      { selector: ".btn" },
      { selector: ".card" }
    ],
    maxCustomPropsPerSelector: 40
  };

  function matchesSelector(target, candidate) {
    const trimmed = candidate.trim();
    if (trimmed === target) return true;
    if (trimmed.indexOf(target) !== -1) return true;
    return false;
  }

  function clampChannel(value) {
    return Math.max(0, Math.min(255, Math.round(value)));
  }

  function toHex(r, g, b) {
    const component = (channel) => clampChannel(channel).toString(16).padStart(2, "0");
    return `#${component(r)}${component(g)}${component(b)}`;
  }

  function normalizeCssColor(value) {
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
      const match = normalized.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*(\d+(?:\.\d+)?))?\)/i);
      if (match) {
        const alpha = match[4] ? parseFloat(match[4]) : 1;
        if (alpha === 0) return null;
        return toHex(parseInt(match[1], 10), parseInt(match[2], 10), parseInt(match[3], 10));
      }
    } catch (error) {
      console.warn("normalizeCssColor failed", error);
      return null;
    }
    return null;
  }

  function isDuplicateColor(candidate, collection) {
    const components = (hex) => {
      const normalized = hex.replace('#', '');
      return [
        parseInt(normalized.slice(0, 2), 16),
        parseInt(normalized.slice(2, 4), 16),
        parseInt(normalized.slice(4, 6), 16)
      ];
    };
    const [r, g, b] = components(candidate);
    return collection.some((existing) => {
      const [er, eg, eb] = components(existing);
      const distance = Math.abs(r - er) + Math.abs(g - eg) + Math.abs(b - eb);
      return distance < 35;
    });
  }

  async function sampleImageColors(src) {
    const buckets = new Map();
    try {
      const response = await fetch(src, { mode: "cors" });
      if (!response.ok) return [];
      const blob = await response.blob();
      const bitmap = await createImageBitmap(blob);
      const canvas = document.createElement("canvas");
      const ctx = canvas.getContext("2d");
      if (!ctx) return [];
      const width = Math.min(64, bitmap.width || 64);
      const height = Math.max(1, Math.round((width / Math.max(bitmap.width, 1)) * Math.max(bitmap.height, 1)));
      canvas.width = width;
      canvas.height = height;
      ctx.drawImage(bitmap, 0, 0, width, height);
      const data = ctx.getImageData(0, 0, width, height).data;
      for (let i = 0; i < data.length; i += 4) {
        const alpha = data[i + 3] ?? 255;
        if (alpha < 32) continue;
        const r = data[i] ?? 0;
        const g = data[i + 1] ?? 0;
        const b = data[i + 2] ?? 0;
        const key = `${r >> 4}-${g >> 4}-${b >> 4}`;
        let bucket = buckets.get(key);
        if (!bucket) {
          bucket = { count: 0, r: 0, g: 0, b: 0, sat: 0 };
          buckets.set(key, bucket);
        }
        bucket.count += 1;
        bucket.r += r;
        bucket.g += g;
        bucket.b += b;
        const maxChannel = Math.max(r, g, b);
        const minChannel = Math.min(r, g, b);
        const saturation = maxChannel === 0 ? 0 : (maxChannel - minChannel) / maxChannel;
        bucket.sat += saturation;
      }

      const area = width * height;
      const minCount = Math.max(6, Math.round(area * 0.008));
      const sorted = Array.from(buckets.values())
        .map((bucket) => {
          const avgR = bucket.r / bucket.count;
          const avgG = bucket.g / bucket.count;
          const avgB = bucket.b / bucket.count;
          return {
            hex: toHex(avgR, avgG, avgB).toLowerCase(),
            count: bucket.count,
            saturation: bucket.sat / bucket.count
          };
        })
        .filter((bucket) => bucket.count >= minCount)
        .sort((a, b) => b.count - a.count);

      const picked = [];
      for (const candidate of sorted) {
        if (candidate.saturation < 0.12 && candidate.hex !== "#000000" && candidate.hex !== "#ffffff") {
          continue;
        }
        if (isDuplicateColor(candidate.hex, picked)) continue;
        picked.push(candidate.hex);
        if (picked.length >= 6) break;
      }

      if (picked.length === 0 && buckets.size > 0) {
        const largest = Array.from(buckets.values()).reduce(
          (acc, bucket) => (bucket.count > acc.count ? bucket : acc),
          { count: 0, r: 0, g: 0, b: 0, sat: 0 }
        );
        if (largest.count > 0) {
          picked.push(toHex(largest.r / largest.count, largest.g / largest.count, largest.b / largest.count).toLowerCase());
        }
      }

      return picked;
    } catch (error) {
      console.warn("sampleImageColors failed", error);
      return [];
    }
  }

  function extractSvgColors(svg) {
    const colors = new Set();
    const attributes = ["fill", "stroke", "stop-color", "color"];
    const walker = document.createTreeWalker(svg, NodeFilter.SHOW_ELEMENT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      attributes.forEach((attr) => {
        const value = node.getAttribute && node.getAttribute(attr);
        const normalized = normalizeCssColor(value);
        if (normalized) {
          colors.add(normalized);
        }
      });
    }
    return Array.from(colors).slice(0, 8);
  }

  async function collectLogoColors() {
    const results = [];
    const seen = new Set();
    const imageSelectors = [
      'img[src*="logo"]',
      'img[alt*="logo" i]',
      'img[class*="logo" i]',
      'img[id*="logo" i]',
      'img[data-logo]',
      'img[src*="brand"]'
    ];
    const svgSelectors = [
      'svg[class*="logo" i]',
      'svg[id*="logo" i]',
      'svg[data-logo]',
      '[class*="logo" i] svg',
      '[id*="logo" i] svg'
    ];

    const imageNodes = new Set();
    imageSelectors.forEach((selector) => {
      document.querySelectorAll(selector).forEach((node) => imageNodes.add(node));
    });

    const svgNodes = new Set();
    svgSelectors.forEach((selector) => {
      document.querySelectorAll(selector).forEach((node) => svgNodes.add(node));
    });

    let processed = 0;
    const maxLogos = 5;

    for (const node of imageNodes) {
      if (processed >= maxLogos) break;
      const src = node.currentSrc || node.src;
      if (!src || seen.has(src)) continue;
      seen.add(src);
      const colors = await sampleImageColors(src);
      const filtered = colors.filter(Boolean);
      if (filtered.length === 0) continue;
      results.push({
        source: src,
        method: "image",
        colors: filtered,
        alt: node.alt || null
      });
      processed += 1;
    }

    for (const svg of svgNodes) {
      if (processed >= maxLogos) break;
      const key = svg.outerHTML.slice(0, 120);
      if (seen.has(key)) continue;
      seen.add(key);
      const colors = extractSvgColors(svg).filter(Boolean);
      if (colors.length === 0) continue;
      results.push({
        source: svg.outerHTML.slice(0, 500),
        method: "svg",
        colors
      });
      processed += 1;
    }

    return results;
  }

  async function collect(options = {}) {
    const config = { ...DEFAULT_OPTIONS, ...options };
    const errors = [];
    const globalDeclarations = [];
    const componentDeclarations = [];

    function pushDeclaration(list, selector, property, value, important, source, atRules) {
      list.push({
        selector,
        property,
        value: value.trim(),
        important,
        source,
        atRules: atRules.slice(),
        type: property.startsWith("--") ? "css-var" : "base"
      });
    }

    function handleStyleRule(rule, source, context, targetSelectors, bucket) {
      const selectors = rule.selectorText.split(",").map((s) => s.trim());
      const matched = selectors.filter((sel) => targetSelectors.some((target) => matchesSelector(target, sel)));
      if (matched.length === 0) {
        return;
      }
      for (const selector of matched) {
        for (let i = 0; i < rule.style.length; i++) {
          const property = rule.style[i];
          if (!property) continue;
          const value = rule.style.getPropertyValue(property);
          const important = rule.style.getPropertyPriority(property) === "important";
          if (property.startsWith("--") || config.baseProperties.includes(property)) {
            pushDeclaration(bucket, selector, property, value, important, source, context.atRules);
          }
        }
      }
    }

    function traverseRules(rules, source, context) {
      for (let i = 0; i < rules.length; i++) {
        const rule = rules[i];
        if (rule.type === CSSRule.STYLE_RULE) {
          handleStyleRule(rule, source, context, config.globalSelectors, globalDeclarations);
          handleStyleRule(rule, source, context, config.componentSelectors, componentDeclarations);
          continue;
        }
        if (rule.type === CSSRule.MEDIA_RULE) {
          traverseRules(rule.cssRules, source, {
            atRules: [...context.atRules, `@media ${rule.conditionText}`]
          });
          continue;
        }
        if (rule.cssRules) {
          const heading = rule.conditionText || rule.cssText.split("{")[0].trim();
          traverseRules(rule.cssRules, source, { atRules: [...context.atRules, heading] });
        }
      }
    }

    const sheets = Array.from(document.styleSheets);
    for (const sheet of sheets) {
      try {
        if (!sheet.cssRules) continue;
        traverseRules(sheet.cssRules, sheet.href || null, { atRules: [] });
      } catch (error) {
        errors.push(`Unable to read stylesheet ${sheet.href || "[inline]"}: ${error.message || error}`);
      }
    }

    const computed = [];
    const defaultProps = config.baseProperties;
    for (const target of config.computedTargets) {
      const nodes = Array.from(document.querySelectorAll(target.selector));
      const limit = target.limit || 3;
      const properties = target.properties || defaultProps;
      for (let index = 0; index < nodes.length && index < limit; index++) {
        const node = nodes[index];
        const style = window.getComputedStyle(node);
        const sample = { selector: target.selector, sampleIndex: index, properties: {}, customProperties: {} };
        for (const property of properties) {
          sample.properties[property] = style.getPropertyValue(property).trim();
        }
        let count = 0;
        for (let i = 0; i < style.length && count < config.maxCustomPropsPerSelector; i++) {
          const property = style[i];
          if (property && property.startsWith("--")) {
            sample.customProperties[property] = style.getPropertyValue(property).trim();
            count += 1;
          }
        }
        computed.push(sample);
      }
    }

    const logos = await collectLogoColors();

    return {
      pageUrl: location.href,
      timestamp: new Date().toISOString(),
      globalDeclarations,
      componentDeclarations,
      computed,
      logos,
      metadata: {
        themeCandidates: {
          documentElementDataset: document.documentElement?.getAttribute("data-theme") || null,
          htmlClass: document.documentElement?.className || null,
          bodyClass: document.body?.className || null,
          bodyDataset: document.body?.getAttribute("data-theme") || null
        },
        scheme: config.scheme || null
      },
      errors
    };
  }

  if (!window.PulseThemeExtractor) {
    window.PulseThemeExtractor = {};
  }

  window.PulseThemeExtractor.collect = collect;
  console.log("PulseThemeExtractor ready. Call PulseThemeExtractor.collect() to gather theme data.");
})();
