import type { Page } from 'playwright';

/**
 * Finds potential category/collection pages from links on the homepage
 */
export async function findCategoryPage(page: Page, baseUrl: string): Promise<string | null> {
  try {
    const categoryLink = await page.evaluate(`
      (function() {
        const baseUrl = ${JSON.stringify(baseUrl)};
        const links = Array.from(document.querySelectorAll('a[href]'));
        
        // Look for common category patterns
        const patterns = [
          /\\/collections?\\//i,
          /\\/shop\\//i,
          /\\/category\\//i,
          /\\/categories?\\//i,
          /\\/products?\\//i,
          /\\/catalog\\//i
        ];
        
        for (const link of links) {
          const href = link.getAttribute('href');
          if (!href) continue;
          
          let fullUrl;
          try {
            fullUrl = new URL(href, baseUrl).href;
          } catch {
            continue;
          }
          
          // Check if it matches a pattern
          for (const pattern of patterns) {
            if (pattern.test(href) || pattern.test(fullUrl)) {
              return fullUrl;
            }
          }
        }
        
        return null;
      })()
    `);
    
    return categoryLink;
  } catch (error) {
    console.warn('[analyzer] Failed to find category page:', error);
    return null;
  }
}

/**
 * Finds potential product/detail pages from links
 */
export async function findProductPage(page: Page, baseUrl: string): Promise<string | null> {
  try {
    const productLink = await page.evaluate(`
      (function() {
        const baseUrl = ${JSON.stringify(baseUrl)};
        const links = Array.from(document.querySelectorAll('a[href]'));
        
        // Look for product patterns
        const patterns = [
          /\\/product\\//i,
          /\\/p\\//i,
          /\\/item\\//i,
          /\\/sku\\//i,
          /\\/detail\\//i,
          /\\/products?\\/[^\\/]+$/i
        ];
        
        for (const link of links) {
          const href = link.getAttribute('href');
          if (!href) continue;
          
          let fullUrl;
          try {
            fullUrl = new URL(href, baseUrl).href;
          } catch {
            continue;
          }
          
          // Check if it matches a pattern
          for (const pattern of patterns) {
            if (pattern.test(href) || pattern.test(fullUrl)) {
              return fullUrl;
            }
          }
        }
        
        return null;
      })()
    `);
    
    return productLink;
  } catch (error) {
    console.warn('[analyzer] Failed to find product page:', error);
    return null;
  }
}

/**
 * Crawls multiple pages from a base URL
 */
export async function crawlPages(
  page: Page,
  baseUrl: string,
  maxPages: number = 3
): Promise<string[]> {
  const pagesToVisit: string[] = [baseUrl];
  const visited = new Set<string>([baseUrl]);
  
  try {
    // Visit homepage first
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(1000);
    
    // Find category page
    if (maxPages > 1) {
      const categoryUrl = await findCategoryPage(page, baseUrl);
      if (categoryUrl && !visited.has(categoryUrl)) {
        pagesToVisit.push(categoryUrl);
        visited.add(categoryUrl);
      }
    }
    
    // Find product page
    if (maxPages > 2 && pagesToVisit.length < maxPages) {
      // Try to find product page from homepage or category page
      let searchPage = page;
      if (pagesToVisit.length > 1) {
        // Navigate to category page first
        try {
          await page.goto(pagesToVisit[1], { waitUntil: 'domcontentloaded', timeout: 30000 });
          await page.waitForTimeout(1000);
          searchPage = page;
        } catch {
          // If category page fails, search from homepage
          await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
          await page.waitForTimeout(1000);
        }
      }
      
      const productUrl = await findProductPage(searchPage, baseUrl);
      if (productUrl && !visited.has(productUrl)) {
        pagesToVisit.push(productUrl);
        visited.add(productUrl);
      }
    }
    
    return pagesToVisit.slice(0, maxPages);
  } catch (error) {
    console.warn('[analyzer] Error during page crawling:', error);
    // Return at least the homepage
    return [baseUrl];
  }
}

