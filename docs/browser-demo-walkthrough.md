# Browser Features Demonstration Walkthrough

This document shows a step-by-step demonstration of what happens when you use each browser feature in Cursor 2.0.

## Demo 1: Basic Navigation and Inspection

### Step 1: Navigate to a Website
**Command:**
```
Navigate to https://example.com
```

**What happens:**
- Browser opens and navigates to the URL
- Page loads completely
- You're ready to inspect or interact

### Step 2: Take a Snapshot
**Command:**
```
Take a snapshot of the page
```

**What you get back:**
```json
{
  "title": "Example Domain",
  "url": "https://example.com",
  "elements": [
    {
      "role": "heading",
      "name": "Example Domain",
      "ref": "heading-1"
    },
    {
      "role": "paragraph",
      "name": "This domain is for use in illustrative examples...",
      "ref": "paragraph-1"
    },
    {
      "role": "link",
      "name": "More information...",
      "ref": "link-more-info",
      "href": "https://www.iana.org/domains/example"
    }
  ]
}
```

### Step 3: Take a Screenshot
**Command:**
```
Take a screenshot
```

**What happens:**
- Screenshot is captured and saved
- You can see the visual state of the page
- Useful for visual verification

---

## Demo 2: Interactive Form Filling

### Step 1: Navigate to a Form Page
**Command:**
```
Navigate to https://example.com/contact-form
```

**What happens:**
- Browser navigates to the form page
- Form loads with input fields

### Step 2: Get Page Structure
**Command:**
```
Show me the page elements
```

**Snapshot reveals:**
- Input fields with their labels
- Submit button
- Form validation messages
- All with unique `ref` identifiers

### Step 3: Fill Out the Form
**Command:**
```
Fill in the name field with "John Doe"
Type "john@example.com" into the email field
Select "United States" from the country dropdown
Click the submit button
```

**What happens step-by-step:**

1. **Name field:**
   ```
   browser_type(
     element="Name input",
     ref="input-name-field",
     text="John Doe"
   )
   ```
   - Focus moves to name field
   - Text "John Doe" appears in the field

2. **Email field:**
   ```
   browser_type(
     element="Email input",
     ref="input-email-field",
     text="john@example.com"
   )
   ```
   - Focus moves to email field
   - Email address is typed in

3. **Country dropdown:**
   ```
   browser_select_option(
     element="Country dropdown",
     ref="select-country",
     values=["United States"]
   )
   ```
   - Dropdown opens
   - "United States" is selected

4. **Submit:**
   ```
   browser_click(
     element="Submit button",
     ref="button-submit"
   )
   ```
   - Button is clicked
   - Form submits

### Step 4: Wait for Confirmation
**Command:**
```
Wait for "Thank you" to appear
```

**What happens:**
- Browser waits until "Thank you" text appears
- Confirms successful submission

---

## Demo 3: Search Flow

### Step 1: Navigate to Search Engine
**Command:**
```
Go to https://www.google.com
```

### Step 2: Perform Search
**Command:**
```
Type "Python programming" into the search box and press Enter
```

**What happens:**
```
browser_type(
  element="Search input",
  ref="input-search",
  text="Python programming",
  submit=True
)
```
- Search box receives focus
- Text is typed
- Enter key is pressed (due to `submit=True`)
- Search executes

### Step 3: Wait for Results
**Command:**
```
Wait for the search results to load
```

**What happens:**
```
browser_wait_for(text="Results")
```
- Browser waits until "Results" text appears
- Ensures page has fully loaded

### Step 4: Click First Result
**Command:**
```
Click on the first search result
```

**What happens:**
```
browser_click(
  element="First search result",
  ref="result-0"
)
```
- First result link is clicked
- Browser navigates to that page

---

## Demo 4: Debugging a Web Application

### Step 1: Navigate to Your App
**Command:**
```
Navigate to http://localhost:3000
```

### Step 2: Interact with the App
**Command:**
```
Click the login button
```

### Step 3: Check for Errors
**Command:**
```
Show me any JavaScript errors in the console
```

**What you get:**
```json
{
  "console_messages": [
    {
      "level": "error",
      "text": "Uncaught TypeError: Cannot read property 'user' of undefined",
      "source": "app.js:42"
    },
    {
      "level": "warning",
      "text": "Deprecated API usage detected",
      "source": "vendor.js:15"
    }
  ]
}
```

### Step 4: Check Network Requests
**Command:**
```
Show me failed network requests
```

**What you get:**
```json
{
  "network_requests": [
    {
      "url": "https://api.example.com/users",
      "method": "GET",
      "status": 404,
      "statusText": "Not Found"
    },
    {
      "url": "https://api.example.com/login",
      "method": "POST",
      "status": 500,
      "statusText": "Internal Server Error"
    }
  ]
}
```

### Step 5: Take Debug Screenshot
**Command:**
```
Take a screenshot for debugging
```

**What happens:**
- Screenshot captured showing current state
- Saved as `debug-screenshot.png`
- Shows visual state when error occurred

---

## Demo 5: Responsive Design Testing

### Test Desktop View
**Command:**
```
Resize browser to 1920x1080 and take a screenshot
```

**What happens:**
```
browser_resize(width=1920, height=1080)
browser_take_screenshot(filename="desktop-view.png")
```
- Browser window resizes to desktop size
- Screenshot shows desktop layout

### Test Tablet View
**Command:**
```
Resize to tablet size (768x1024) and screenshot
```

**What happens:**
```
browser_resize(width=768, height=1024)
browser_take_screenshot(filename="tablet-view.png")
```
- Browser resizes to tablet dimensions
- Layout adjusts responsively
- Screenshot shows tablet view

### Test Mobile View
**Command:**
```
Resize to mobile size (375x667) and screenshot
```

**What happens:**
```
browser_resize(width=375, height=667)
browser_take_screenshot(filename="mobile-view.png")
```
- Browser resizes to mobile dimensions
- Layout shows mobile-optimized view
- Screenshot shows mobile layout

---

## Demo 6: Complex Interactions

### Hover Menu
**Command:**
```
Hover over the Products menu item
```

**What happens:**
```
browser_hover(
  element="Products menu",
  ref="menu-products"
)
```
- Mouse hovers over menu item
- Dropdown menu appears (if CSS:hover triggers it)
- Submenu becomes visible

### Keyboard Navigation
**Command:**
```
Press the Escape key to close the modal
```

**What happens:**
```
browser_press_key(key="Escape")
```
- Escape key is pressed
- Modal dialog closes (if it listens for Escape)

### Multiple Interactions
**Command:**
```
Type "test" in the search box, press Tab, type "filter" in the filter box, then press Enter
```

**What happens:**
```
browser_type(element="Search", ref="search", text="test")
browser_press_key(key="Tab")
browser_type(element="Filter", ref="filter", text="filter")
browser_press_key(key="Enter")
```
- First field gets "test"
- Tab moves focus to next field
- Second field gets "filter"
- Enter submits the form

---

## Demo 7: Web Scraping

### Step 1: Navigate and Wait
**Command:**
```
Navigate to https://example.com/products and wait for products to load
```

### Step 2: Get Product List
**Command:**
```
Take a snapshot to see all products
```

**Snapshot shows:**
```json
{
  "elements": [
    {
      "role": "heading",
      "name": "Product 1: Laptop",
      "ref": "product-1-title"
    },
    {
      "role": "paragraph",
      "name": "$999.99",
      "ref": "product-1-price"
    },
    {
      "role": "link",
      "name": "View Details",
      "ref": "product-1-link"
    }
    // ... more products
  ]
}
```

### Step 3: Extract Information
You can now extract:
- Product names
- Prices
- Links
- Descriptions

All from the structured snapshot data!

---

## Visual Timeline Example

Here's what a complete interaction looks like:

```
1. Navigate to page
   └─> Browser opens → Page loads → Ready

2. Take snapshot
   └─> Page structure analyzed → Elements identified → References assigned

3. Click button
   └─> Element found → Click executed → Action triggered

4. Wait for response
   └─> Browser monitors → Text appears → Continue

5. Type in field
   └─> Field focused → Text entered → Value set

6. Submit form
   └─> Submit clicked → Form submits → Response received

7. Screenshot
   └─> Page rendered → Screenshot captured → Saved
```

---

## Pro Tips from These Demos

1. **Always snapshot first** - Get element references before clicking
2. **Wait strategically** - Use `wait_for` before interacting with dynamic content
3. **Debug with console** - Check console messages when things break
4. **Monitor network** - Use network requests to verify API calls
5. **Visual verification** - Screenshots help confirm visual state
6. **Responsive testing** - Resize browser to test different viewports

---

## Try It Yourself!

In Cursor, you can:

1. Ask me to navigate to any website
2. Request snapshots to see page structure
3. Ask me to interact with elements
4. Request screenshots for verification
5. Ask me to debug by checking console/network
6. Test responsive designs by resizing

Just describe what you want to do in natural language, and I'll use the appropriate browser tools!

