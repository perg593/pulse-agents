# Quick Start: Cursor 2.0 Browser Features

## 🚀 Get Started in 3 Steps

### Step 1: Navigate to a Website
Simply ask Cursor to navigate to any URL:

```
Navigate to https://example.com
```

Or use the tool directly:
- `browser_navigate(url="https://example.com")`

### Step 2: Inspect the Page
Take a snapshot to see what elements are available:

```
Take a snapshot of the page
```

- `browser_snapshot()` - Returns structured data about all page elements

### Step 3: Interact with Elements
Click, type, or interact with elements using their references:

```
Click the "Search" button
Type "hello" into the search box
```

- `browser_click(element="Search button", ref="element-ref")`
- `browser_type(element="Search box", ref="element-ref", text="hello")`

## 📋 Common Commands

### Navigation
- **Navigate**: "Go to https://example.com"
- **Go Back**: "Go back to the previous page"
- **Take Screenshot**: "Take a screenshot"

### Interaction
- **Click**: "Click the submit button"
- **Type**: "Type 'test' into the search field"
- **Select**: "Select 'United States' from the country dropdown"
- **Hover**: "Hover over the menu item"

### Waiting
- **Wait**: "Wait for the page to load"
- **Wait for text**: "Wait until 'Loading complete' appears"

### Debugging
- **Check errors**: "Show me console errors"
- **Check network**: "Show me failed network requests"

## 💡 Example Conversations

### Example 1: Search Something
```
You: Navigate to Google and search for "Python tutorials"
AI: [Navigates to Google, finds search box, types query, submits]
```

### Example 2: Fill a Form
```
You: Go to example.com/form and fill it out with my name and email
AI: [Navigates, finds form fields, fills them in, submits]
```

### Example 3: Debug Your App
```
You: Check my app at localhost:3000 for JavaScript errors
AI: [Navigates, checks console messages, reports any errors]
```

### Example 4: Test Responsive Design
```
You: Take screenshots of my site at mobile, tablet, and desktop sizes
AI: [Resizes browser, takes screenshots at each size]
```

## 🎯 Tips

1. **Be Specific**: Describe elements clearly ("the blue submit button" vs "button")
2. **Wait for Loads**: Always wait for dynamic content before interacting
3. **Use Snapshots**: Ask for snapshots to see available elements
4. **Debug with Console**: Check console messages when things don't work
5. **Screenshots Help**: Request screenshots to verify visual state

## 🔧 Available Tools

| Tool | Purpose | Example |
|------|---------|---------|
| `browser_navigate` | Go to URL | Navigate to any website |
| `browser_snapshot` | Get page structure | See all elements |
| `browser_click` | Click elements | Click buttons, links |
| `browser_type` | Enter text | Fill forms |
| `browser_select_option` | Select dropdowns | Choose options |
| `browser_hover` | Hover elements | Trigger hover menus |
| `browser_press_key` | Press keys | Press Enter, Escape |
| `browser_wait_for` | Wait for content | Wait for text/events |
| `browser_take_screenshot` | Capture visuals | Take screenshots |
| `browser_console_messages` | Get console logs | Debug JavaScript |
| `browser_network_requests` | Get network calls | Debug API calls |
| `browser_resize` | Resize window | Test responsive |

## 📚 Learn More

- See `docs/preview/browser-features.md` for detailed documentation
- See `examples/browser_examples.py` for code examples

## ⚠️ Important Notes

- Element references come from `browser_snapshot()` - use snapshots first!
- Always wait for dynamic content before interacting
- Browser sessions may be ephemeral (don't rely on persistent state)
- Some sites may require special handling for JavaScript-heavy pages

