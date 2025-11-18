import express from 'express';
import cors from 'cors';
import { analyzeSite } from './analyzeSite.js';
import { generateThemesFromSnapshot } from './generateThemes.js';
import type { AnalyzeSiteRequest, AnalyzeSiteResponse } from '../src/types/siteSnapshot.js';

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

app.post('/api/analyze-site', async (req, res) => {
  try {
    const { url, maxPages = 3 }: AnalyzeSiteRequest = req.body;
    
    if (!url || typeof url !== 'string') {
      return res.status(400).json({ error: 'Invalid URL provided' });
    }
    
    // Validate URL format
    try {
      new URL(url);
    } catch {
      return res.status(400).json({ error: 'Invalid URL format' });
    }
    
    console.log(`[analyzer] Analyzing site: ${url} (maxPages: ${maxPages})`);
    
    // Analyze the site
    const snapshot = await analyzeSite(url, maxPages);
    
    // Generate 4 themes from snapshot
    const themes = generateThemesFromSnapshot(snapshot);
    
    const response: AnalyzeSiteResponse = {
      snapshot,
      themes
    };
    
    console.log(`[analyzer] Generated ${themes.length} themes for ${url}`);
    
    res.json(response);
  } catch (error) {
    console.error('[analyzer] Error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const errorStack = error instanceof Error ? error.stack : undefined;
    
    // Check for common Playwright errors
    if (errorMessage.includes('Executable doesn\'t exist') || errorMessage.includes('BrowserType')) {
      console.error('[analyzer] Playwright browsers not installed. Run: npx playwright install chromium');
    }
    
    console.error('[analyzer] Stack:', errorStack);
    
    res.status(500).json({ 
      error: 'Failed to analyze site',
      message: errorMessage,
      hint: errorMessage.includes('Executable doesn\'t exist') || errorMessage.includes('BrowserType')
        ? 'Playwright browsers may not be installed. Run: npx playwright install chromium'
        : undefined
    });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`[analyzer] Server running on http://localhost:${PORT}`);
});

