# Cursor 2.0 Browser Features Guide

This guide demonstrates how to use the new browser automation features in Cursor 2.0. These features allow you to interact with web pages programmatically, test web applications, scrape data, and automate browser tasks.

## Available Browser Tools

### 1. Navigation

#### Navigate to a URL
Navigate to any website to start interacting with it.

```python
# Navigate to a webpage
browser_navigate(url="https://example.com")
```

#### Navigate Back
Go back to the previous page in browser history.

```python
browser_navigate_back()
```

### 2. Page Inspection

#### Capture Accessibility Snapshot
Get a structured snapshot of the page's accessibility tree. This is better than screenshots for understanding page structure.

```python
# Get page snapshot
snapshot = browser_snapshot()
# Returns accessibility information about all elements on the page
```

#### Take Screenshot
Capture a visual screenshot of the page or specific elements.

```python
# Full page screenshot
browser_take_screenshot(fullPage=True)

# Element screenshot
browser_take_screenshot(ref="css-selector", element="Button element")

# Screenshot with custom filename
browser_take_screenshot(filename="my-page.png")
```

### 3. Element Interaction

#### Click Elements
Click on buttons, links, or any clickable elements.

```python
# Single click
browser_click(element="Submit button", ref="element-reference")

# Double click
browser_click(element="File icon", ref="element-reference", doubleClick=True)

# Right click (modifier)
browser_click(element="Context menu", ref="element-reference", button="right")
```

#### Type Text
Enter text into input fields, textareas, or contenteditable elements.

```python
# Normal typing
browser_type(element="Search input", ref="element-reference", text="query")

# Slow typing (one character at a time)
browser_type(element="Password field", ref="element-reference", text="password", slowly=True)

# Type and submit
browser_type(element="Search box", ref="element-reference", text="query", submit=True)
```

#### Hover Over Elements
Hover over elements to trigger hover effects or tooltips.

```python
browser_hover(element="Dropdown menu", ref="element-reference")
```

#### Select Dropdown Options
Select options from dropdown/select elements.

```python
# Single selection
browser_select_option(element="Country dropdown", ref="element-reference", values=["USA"])

# Multiple selection
browser_select_option(element="Tags selector", ref="element-reference", values=["tag1", "tag2"])
```

### 4. Keyboard Actions

#### Press Keys
Simulate keyboard key presses.

```python
# Press Enter
browser_press_key(key="Enter")

# Press Escape
browser_press_key(key="Escape")

# Press arrow keys
browser_press_key(key="ArrowDown")
browser_press_key(key="ArrowUp")
browser_press_key(key="ArrowLeft")
browser_press_key(key="ArrowRight")

# Press modifier keys
browser_press_key(key="Meta")  # Command on Mac
browser_press_key(key="Control")  # Ctrl on Windows/Linux
```

### 5. Waiting and Timing

#### Wait for Text
Wait for specific text to appear or disappear on the page.

```python
# Wait for text to appear
browser_wait_for(text="Loading complete")

# Wait for text to disappear
browser_wait_for(textGone="Loading...")

# Wait for specific time
browser_wait_for(time=5)  # Wait 5 seconds
```

### 6. Page Information

#### Get Console Messages
Retrieve all browser console messages (errors, warnings, logs).

```python
console_messages = browser_console_messages()
# Returns array of console messages with level, text, and source
```

#### Get Network Requests
See all network requests made by the page (XHR, fetch, etc.).

```python
network_requests = browser_network_requests()
# Returns array of network requests with URL, method, status, etc.
```

### 7. Window Management

#### Resize Browser Window
Change the browser window size for responsive testing.

```python
# Set window size
browser_resize(width=1920, height=1080)

# Mobile viewport
browser_resize(width=375, height=667)
```

## Common Use Cases

### Example 1: Web Scraping
```python
# Navigate to a page
browser_navigate(url="https://example.com/products")

# Wait for content to load
browser_wait_for(text="Products")

# Take snapshot to see structure
snapshot = browser_snapshot()

# Click on a product
browser_click(element="Product card", ref="product-1")

# Get product details
snapshot = browser_snapshot()
```

### Example 2: Form Filling
```python
# Navigate to form page
browser_navigate(url="https://example.com/signup")

# Fill in form fields
browser_type(element="Name input", ref="name-field", text="John Doe")
browser_type(element="Email input", ref="email-field", text="john@example.com")
browser_type(element="Password input", ref="password-field", text="secure123", slowly=True)

# Select from dropdown
browser_select_option(element="Country", ref="country-select", values=["USA"])

# Submit form
browser_click(element="Submit button", ref="submit-btn")

# Wait for success message
browser_wait_for(text="Registration successful")
```

### Example 3: Testing User Flows
```python
# Navigate to homepage
browser_navigate(url="https://example.com")

# Search for something
browser_type(element="Search box", ref="search-input", text="test query", submit=True)

# Wait for results
browser_wait_for(text="Search results")

# Click on first result
browser_click(element="First result", ref="result-0")

# Verify page loaded
browser_wait_for(text="Details")
```

### Example 4: Debugging Web Applications
```python
# Navigate to your app
browser_navigate(url="http://localhost:3000")

# Interact with the page
browser_click(element="Button", ref="button-ref")

# Check console for errors
console_messages = browser_console_messages()
for msg in console_messages:
    if msg['level'] == 'error':
        print(f"Error: {msg['text']}")

# Check network requests
network_requests = browser_network_requests()
failed_requests = [req for req in network_requests if req['status'] >= 400]
print(f"Failed requests: {len(failed_requests)}")
```

## Best Practices

1. **Always wait for content**: Use `browser_wait_for()` before interacting with elements that load dynamically
2. **Use snapshots strategically**: Take snapshots to understand page structure before clicking
3. **Handle errors gracefully**: Check console messages and network requests for debugging
4. **Test responsive designs**: Use `browser_resize()` to test different viewport sizes
5. **Use slow typing for sensitive fields**: Use `slowly=True` for password fields or fields with validation
6. **Take screenshots for visual verification**: Use screenshots to verify UI state

## Tips and Tricks

- **Element References**: The `ref` parameter comes from the accessibility snapshot. Use `browser_snapshot()` first to get element references
- **Text Matching**: `browser_wait_for()` uses text matching, so be specific with your text patterns
- **Modifier Keys**: Use `modifiers` array in `browser_click()` for complex interactions (Cmd+Click, Ctrl+Click, etc.)
- **Console Debugging**: Always check `browser_console_messages()` when debugging web applications
- **Network Monitoring**: Use `browser_network_requests()` to verify API calls and data fetching

## Limitations

- Browser sessions are ephemeral - each conversation may start a new session
- Some JavaScript-heavy sites may require waiting for dynamic content
- Browser automation respects rate limits and CORS policies
- Some interactions may require proper element references from snapshots

## Getting Started

1. Start by navigating to a simple page: `browser_navigate(url="https://example.com")`
2. Take a snapshot to see available elements: `browser_snapshot()`
3. Interact with elements using their references from the snapshot
4. Use screenshots and console messages to debug and verify

Happy browsing! 🚀

