<!-- File: STEP-01-IA-and-Primary-Actions.md -->
# Pulse Insights — Demo Studio
## Step 1: Information Architecture & Primary Actions

### Purpose
Make the demo flow unambiguous: **Pick an Agent → Match the Site → Trigger It**. This step defines IA, labels, microcopy, and the preview toolbar—no business logic changes.

---

## A) IA Overview

**Left rail (accordion, single section open):**
1. **Agent**
2. **Appearance**
3. **Triggers**
4. **Examples**
5. **Tools**

**Preview toolbar (above the preview iframe):**
- URL field | Device (Desktop / Tablet / Mobile) | Placement (BR / BL / TR / TL) | Safe‑area toggle | Reload

Only one **Primary** button appears per section.

---

## B) Controls and Labels (Exact)

### 1) Agent
- **Select agent** (combobox; searchable)
- **Launch Agent** (primary)
  - Tooltip: “Show the selected agent on the page.”
- **Placement** (segmented): Bottom right / Bottom left / Top right / Top left
- **Variant** (select): Card / Banner / Modal
- **Show embed snippet** (link)

**Empty state:** “Pick an Agent to begin. Load a demo from *Examples* if you’re exploring.”

---

### 2) Appearance
Tabs:
- **Auto (from URL)**
  - `Enter a site URL` (url)
  - **Generate theme** (primary)
    - Tooltip: “Scan the URL for colors and typography; we’ll propose four variants.”
  - **Suggestions** grid (2 columns)
  - **Empty state:** “Enter a URL and generate suggestions. You can still tweak Quick knobs.”
- **Manual**
  - `Saved themes` (select)
  - **Apply** (secondary)
  - **Applied styles** list (removable items)

**Quick knobs** (collapsible):
- Brand color (color)
- Corner radius (range 0–16)
- Density (select: Cozy / Comfortable / Compact)

---

### 3) Triggers
Buttons:
- **Present now** (primary)
- Simulate exit‑intent
- Simulate 60% scroll
- Simulate 10s idle
- Simulate rage click

Subtext: “Simulate behavior to demo firing without real user actions.”

---

### 4) Examples
- `Industry` (All industries, SaaS, Retail, Financial Services, Healthcare)
- `Use‑case` (—, Churn predictor prompt, Pricing objection, Implementation partner eval)
- Inline info: “Examples swap in prewritten copy and logic on top of your selected agent. You can revert any time.”

---

### 5) Tools
Badges:
- **Tag**: Ready / Not found
- **Agent**: Idle / Presenting

Buttons:
- Show event log
- Reset demo (danger)

---

## C) Preview Toolbar (Exact)

- **URL**: placeholder `https://target-site.com`
- **Device**: Desktop / Tablet / Mobile
- **Placement**: BR / BL / TR / TL (mirrors Agent → Placement)
- **Safe area**: toggle (shows green border)
- **Reload**: icon button

---

## D) Visual & Content Standards

- **Typography**: Inter (or system UI), base 16px; headings 18/22/28.
- **Spacing scale**: 4, 8, 12, 16, 24, 32.
- **Border radius**: default 8.
- **Color use**: neutral UI; reserve accent for primary CTAs & status.
- **Iconography**: Lucide/Feather.
- **Microcopy** (exact):
  - Launch Agent: “Show the selected agent on the page.”
  - Generate theme: “Scan the URL for colors and typography; we’ll propose four variants.”
  - Present now: “Force the agent to appear. Ignores behavioral rules.”
  - Show event log: “Open a live stream of tag events, trigger checks, and presentation state.”

---

## E) Accessibility

- Keyboard focus visible on all controls.
- Contrast AA minimum (body text ≥ 4.5:1).
- ARIA live region for status changes (e.g., “Presenting”, “Tag ready”).
- Body text 16px desktop, 15px mobile.

---

## F) Acceptance Criteria (Step 1)

1. Left rail renders **Agent / Appearance / Triggers / Examples / Tools** as a single‑open accordion.
2. One **Primary** button per section (Agent: Launch Agent; Appearance: Generate theme; Triggers: Present now).
3. Preview toolbar includes URL, Device, Placement, Safe‑area toggle, Reload.
4. Placement control in toolbar mirrors Agent → Placement (bidirectional).
5. Status badges show Tag (Ready/Not found) and Agent (Idle/Presenting).
6. All labels and microcopy match this document exactly.