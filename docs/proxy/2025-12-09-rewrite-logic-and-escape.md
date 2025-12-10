# ⚙️ Rewrite Logic and Block Escape Navigation

## **Objective**

Fix two issues in the PI-Proxy system:

1. **Malformed attribute strings are being rewritten as URLs**, producing invalid navigation such as `https://www.pulseinsights.com/"about:blank"`.
2. **The iframe displaying previewed sites is allowed to escape-navigate**, letting upstream scripts redirect the parent container (e.g., to pulseinsights.com).

Both fixes must be implemented in the repo, strictly following the instructions below.

---

==========================================================

# PART A — HARDEN URL REWRITE LOGIC (MANDATORY)

==========================================================

## **A1. Introduce a URL validation utility**

Create or update a module (Codex chooses correct location based on repo structure) that exports:

```ts
export function isRewritableUrl(value: string): boolean;
```

### **A1.1. The function must return `false` for all of the following:**

* Strings beginning with `'` or `"`
* Strings containing *any* stray quotes inside the value
  *(meaning: any `'` or `"` that is not a paired wrapping quote)*
* Values starting with `javascript:`, `data:`, `blob:`, `chrome:`, `about:`
* Empty or whitespace-only values
* Values lacking a URL protocol and not root-relative
  *(e.g., `foo/bar`, `fonts.googleapis.com/foo.css` WITHOUT `https://`)*

### **A1.2. The function must return `true` only for:**

* Absolute URLs starting with `http://` or `https://`
* Protocol-relative URLs starting with `//`
* Root-relative paths starting with `/`

No other form is accepted.

---

## **A2. Restrict rewriting to a fixed whitelist of attributes**

Codex must implement:

```ts
const URL_ATTRS = new Set([
  "src",
  "href",
  "action",
  "formaction",
  "poster",
  "data-src",
  "data-href",
  "xlink:href",
  "content", // only for <meta http-equiv="refresh">
]);
```

Codex must update the HTMLRewriter so:

* Only attributes in the whitelist are considered.
* For `<meta http-equiv="refresh">`, only rewrite if the content contains a `url=...` directive.

---

## **A3. Apply rewriting ONLY if `isRewritableUrl(attrValue)` returns true**

Pseudo-code Codex must implement inside HTMLRewriter handlers:

```ts
if (URL_ATTRS.has(attrName)) {
  if (isRewritableUrl(attrValue)) {
    element.setAttribute(attrName, rewriteUrl(attrValue, PROXY_ORIGIN));
  } else {
    // skip; do NOT mutate the attribute
  }
}
```

There must be **no fallback logic** that rewrites partially valid values.
If `isRewritableUrl` is false → do nothing.

---

## **A4. Fix CSS `url(...)` rewriting**

When rewriting CSS, Codex must:

1. Extract the inner URL of `url(...)`.
2. Strip wrapping `'` or `"`.
3. Apply `isRewritableUrl`.
4. If false → preserve the original `url(...)` unchanged.
5. If true → rewrite using existing rewrite function.

---

==========================================================

# PART B — BLOCK ESCAPE NAVIGATION (MANDATORY)

==========================================================

## **B1. Update iframe sandbox attributes**

Codex must locate the code in your preview dashboard that creates the preview iframe (the one that loads `/proxy?url=...`).

Replace the iframe element with one that includes exactly the following sandbox permissions:

```
sandbox="allow-scripts allow-same-origin allow-forms allow-downloads"
```

### **B1.1. Codex must remove the following if present:**

* `allow-top-navigation`
* `allow-top-navigation-by-user-activation`
* `allow-popups`
* `allow-popups-to-escape-sandbox`

This guarantees no script in the iframe can redirect the parent window.

---

## **B2. Add referrer policy**

Apply:

```
referrerpolicy="no-referrer"
```

This prevents upstream sites from receiving the proxy URL in headers.

---

==========================================================

# PART C — TEST REQUIREMENTS (MANDATORY)

==========================================================

Codex must generate or update automated tests such that:

### **C1. Valid rewrite cases (should rewrite):**

```
/foo/bar.png
https://example.com/a/b
//cdn.example.com/lib.js
/foo
```

### **C2. Must NOT rewrite (must remain unchanged):**

```
"about:blank"
'about:blank'
about:blank
"//fonts.googleapis.com"
"'https://fonts.googleapis.com/css2'"
javascript:alert(1)
data:image/png;base64,iVBORw...
fonts.googleapis.com/foo.css
```

### **C3. iframe escape prevention test**

Simulate inside iframe JS:

```js
window.top.location = "https://pulseinsights.com";
window.location = "https://njtransit.com";
document.location.assign("https://google.com");
```

The parent window URL **must not change**.

Implementation detail: Codex chooses the appropriate mocking / testing framework based on current repo.

---

==========================================================

# PART D — NON-NEGOTIABLE CODING REQUIREMENTS

==========================================================

Codex must adhere to:

### **D1. No global behavior changes beyond those defined here.**

### **D2. No rewriting of any attribute not explicitly listed.**

### **D3. No attempts to interpret malformed URLs. If invalid → skip.**

### **D4. No changes to existing business logic for analytics blocking, passthrough domains, or challenge handling.**

### **D5. All diffs must compile and TypeScript must pass.**

---

==========================================================

# PART E — DELIVERABLES Codex Max MUST OUTPUT

==========================================================

Codex must produce:

1. **A new or updated `isRewritableUrl` utility.**
2. **HTMLRewriter updates** implementing the whitelist + safe rewrite flow.
3. **CSS rewrite updates** enforcing the new rules.
4. **Iframe code update** with strict sandbox and referrer policy.
5. **Automated tests** covering positive and negative rewrite cases + escape prevention.
6. Any necessary import updates or module adjustments.

---

# END OF SPEC