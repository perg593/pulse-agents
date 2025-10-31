#!/usr/bin/env python3
"""
Example: Using Cursor 2.0 Browser Features

This script demonstrates how to use the browser automation features
available in Cursor 2.0. Copy these patterns into your Cursor conversations.
"""

# ============================================================================
# BASIC NAVIGATION
# ============================================================================

def example_navigation():
    """Navigate to websites"""
    # Navigate to a page
    browser_navigate(url="https://example.com")
    
    # Go back
    browser_navigate_back()
    
    # Navigate to another page
    browser_navigate(url="https://www.google.com")


# ============================================================================
# PAGE INSPECTION
# ============================================================================

def example_inspection():
    """Inspect page structure and content"""
    # Get accessibility snapshot (structured page data)
    snapshot = browser_snapshot()
    # This returns all elements with their roles, names, and references
    
    # Take a screenshot
    browser_take_screenshot(fullPage=True, filename="full-page.png")
    
    # Screenshot specific element
    browser_take_screenshot(
        ref="button-submit",
        element="Submit button",
        filename="button.png"
    )


# ============================================================================
# ELEMENT INTERACTION
# ============================================================================

def example_form_interaction():
    """Fill out and submit a form"""
    # Navigate to form page
    browser_navigate(url="https://example.com/form")
    
    # Wait for form to load
    browser_wait_for(text="Contact Form")
    
    # Get page snapshot to find element references
    snapshot = browser_snapshot()
    
    # Fill in text fields
    browser_type(
        element="Name input field",
        ref="input-name",  # From snapshot
        text="John Doe"
    )
    
    browser_type(
        element="Email input",
        ref="input-email",
        text="john@example.com"
    )
    
    # Slow typing for password fields
    browser_type(
        element="Password field",
        ref="input-password",
        text="SecurePassword123",
        slowly=True
    )
    
    # Select from dropdown
    browser_select_option(
        element="Country dropdown",
        ref="select-country",
        values=["United States"]
    )
    
    # Submit form
    browser_click(
        element="Submit button",
        ref="button-submit"
    )
    
    # Wait for success message
    browser_wait_for(text="Thank you")


# ============================================================================
# SEARCH AND NAVIGATION FLOW
# ============================================================================

def example_search_flow():
    """Perform a search and navigate results"""
    # Navigate to search page
    browser_navigate(url="https://www.google.com")
    
    # Wait for page load
    browser_wait_for(text="Google")
    
    # Get snapshot to find search box
    snapshot = browser_snapshot()
    
    # Type search query and submit
    browser_type(
        element="Search input",
        ref="input-search",
        text="Python programming",
        submit=True
    )
    
    # Wait for results
    browser_wait_for(text="Results")
    
    # Click first result
    browser_click(
        element="First search result",
        ref="result-0"
    )
    
    # Wait for page to load
    browser_wait_for(time=2)


# ============================================================================
# DEBUGGING WEB APPLICATIONS
# ============================================================================

def example_debugging():
    """Debug a web application"""
    # Navigate to your app
    browser_navigate(url="http://localhost:3000")
    
    # Interact with the app
    browser_click(element="Login button", ref="btn-login")
    
    # Check for JavaScript errors
    console_messages = browser_console_messages()
    errors = [msg for msg in console_messages if msg.get('level') == 'error']
    
    if errors:
        print("JavaScript Errors Found:")
        for error in errors:
            print(f"  - {error.get('text')}")
    
    # Check network requests
    network_requests = browser_network_requests()
    failed = [req for req in network_requests if req.get('status', 0) >= 400]
    
    if failed:
        print("Failed Network Requests:")
        for req in failed:
            print(f"  - {req.get('method')} {req.get('url')}: {req.get('status')}")
    
    # Take screenshot for visual debugging
    browser_take_screenshot(filename="debug-screenshot.png")


# ============================================================================
# COMPLEX INTERACTIONS
# ============================================================================

def example_complex_interactions():
    """Advanced interaction patterns"""
    # Navigate to page
    browser_navigate(url="https://example.com")
    
    # Hover to reveal dropdown
    browser_hover(element="Menu item", ref="menu-products")
    
    # Wait for dropdown to appear
    browser_wait_for(text="Product Categories")
    
    # Click dropdown item
    browser_click(element="Category link", ref="category-electronics")
    
    # Double-click for special actions
    browser_click(
        element="File icon",
        ref="icon-file",
        doubleClick=True
    )
    
    # Right-click for context menu
    browser_click(
        element="Text element",
        ref="text-select",
        button="right"
    )
    
    # Keyboard navigation
    browser_press_key(key="Escape")  # Close modal
    browser_press_key(key="Tab")  # Navigate focus
    browser_press_key(key="Enter")  # Activate focused element


# ============================================================================
# RESPONSIVE TESTING
# ============================================================================

def example_responsive_testing():
    """Test different screen sizes"""
    # Desktop view
    browser_resize(width=1920, height=1080)
    browser_navigate(url="https://example.com")
    browser_take_screenshot(filename="desktop.png")
    
    # Tablet view
    browser_resize(width=768, height=1024)
    browser_take_screenshot(filename="tablet.png")
    
    # Mobile view
    browser_resize(width=375, height=667)
    browser_take_screenshot(filename="mobile.png")


# ============================================================================
# WEB SCRAPING EXAMPLE
# ============================================================================

def example_scraping():
    """Scrape data from a webpage"""
    # Navigate to target page
    browser_navigate(url="https://example.com/products")
    
    # Wait for products to load
    browser_wait_for(text="Products")
    
    # Get page structure
    snapshot = browser_snapshot()
    
    # Extract product information from snapshot
    # The snapshot contains structured data about all elements
    
    # Click to see more details
    browser_click(element="Product card", ref="product-1")
    
    # Wait for details page
    browser_wait_for(text="Product Details")
    
    # Get detailed snapshot
    details_snapshot = browser_snapshot()
    
    # Navigate back to list
    browser_navigate_back()


# ============================================================================
# WORKFLOW: COMPLETE E-COMMERCE TEST
# ============================================================================

def example_ecommerce_workflow():
    """Complete e-commerce purchase flow"""
    # 1. Navigate to store
    browser_navigate(url="https://example-store.com")
    browser_wait_for(text="Welcome")
    
    # 2. Search for product
    browser_type(
        element="Search bar",
        ref="search-input",
        text="laptop",
        submit=True
    )
    browser_wait_for(text="Search Results")
    
    # 3. Click first product
    browser_click(element="Product", ref="product-laptop-1")
    browser_wait_for(text="Add to Cart")
    
    # 4. Add to cart
    browser_click(element="Add to Cart button", ref="btn-add-cart")
    browser_wait_for(text="Added to cart")
    
    # 5. Go to cart
    browser_click(element="Cart icon", ref="icon-cart")
    browser_wait_for(text="Shopping Cart")
    
    # 6. Proceed to checkout
    browser_click(element="Checkout button", ref="btn-checkout")
    browser_wait_for(text="Checkout")
    
    # 7. Fill shipping info
    browser_type(element="Name", ref="input-name", text="John Doe")
    browser_type(element="Address", ref="input-address", text="123 Main St")
    browser_type(element="City", ref="input-city", text="New York")
    browser_select_option(element="State", ref="select-state", values=["NY"])
    browser_type(element="Zip", ref="input-zip", text="10001")
    
    # 8. Continue to payment
    browser_click(element="Continue button", ref="btn-continue")
    browser_wait_for(text="Payment")
    
    # 9. Fill payment (example - be careful with real data!)
    browser_type(element="Card number", ref="input-card", text="1234 5678 9012 3456")
    browser_type(element="Expiry", ref="input-expiry", text="12/25")
    browser_type(element="CVV", ref="input-cvv", text="123", slowly=True)
    
    # 10. Place order
    browser_click(element="Place Order button", ref="btn-place-order")
    browser_wait_for(text="Order Confirmed")
    
    # 11. Take confirmation screenshot
    browser_take_screenshot(filename="order-confirmation.png")


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    print("This is a reference script for Cursor 2.0 browser features.")
    print("Copy the functions you need into your Cursor conversation.")
    print("\nAvailable examples:")
    print("  - example_navigation()")
    print("  - example_inspection()")
    print("  - example_form_interaction()")
    print("  - example_search_flow()")
    print("  - example_debugging()")
    print("  - example_complex_interactions()")
    print("  - example_responsive_testing()")
    print("  - example_scraping()")
    print("  - example_ecommerce_workflow()")

