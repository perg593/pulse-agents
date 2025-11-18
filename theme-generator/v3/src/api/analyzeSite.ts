import type { AnalyzeSiteRequest, AnalyzeSiteResponse } from '../types/siteSnapshot';

const API_BASE_URL = (import.meta as any).env?.VITE_API_URL || 'http://localhost:3001';

/**
 * Calls the backend analyzer API to analyze a site and generate themes
 */
export async function analyzeSiteApi(request: AnalyzeSiteRequest): Promise<AnalyzeSiteResponse> {
  const response = await fetch(`${API_BASE_URL}/api/analyze-site`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(request)
  });
  
  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    const errorMessage = error.error || `HTTP ${response.status}: ${response.statusText}`;
    const fullMessage = error.hint ? `${errorMessage}\n\n${error.hint}` : errorMessage;
    const errorObj = new Error(fullMessage);
    (errorObj as any).hint = error.hint;
    throw errorObj;
  }
  
  return response.json();
}

