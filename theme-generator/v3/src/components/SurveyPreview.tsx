import { useEffect, useState } from 'react';
import { useThemeStore } from '../stores/themeStore';
import { VIEWPORT_WIDTHS } from '../types/theme';
import { ViewportToggle } from './ViewportToggle';
import { compileTheme } from '../theme/compileTheme';

export function SurveyPreview() {
  const activeTheme = useThemeStore((state) => state.getActiveTheme());
  const viewport = useThemeStore((state) => state.viewport);
  const [compiledCSS, setCompiledCSS] = useState<string>('');

  // Compile theme to CSS whenever theme changes
  useEffect(() => {
    if (!activeTheme) {
      setCompiledCSS('');
      return;
    }
    
    try {
      const css = compileTheme(activeTheme);
      setCompiledCSS(css);
    } catch (error) {
      console.error('Failed to compile theme:', error);
      setCompiledCSS('');
    }
  }, [activeTheme]);

  const previewWidth = VIEWPORT_WIDTHS[viewport];

  if (!activeTheme) {
    return (
      <div className="survey-preview">
        <div className="preview-header">
          <h2>Preview</h2>
        </div>
        <div className="preview-empty">
          <p>No theme selected</p>
        </div>
      </div>
    );
  }

  // Simulated Pulse survey HTML
  const surveyHTML = `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          ${compiledCSS}
        </style>
      </head>
      <body>
        <div id="_pi_surveyWidgetContainer">
          <div id="_pi_surveyWidget">
            <div class="_pi_question">
              What's your biggest CX Challenge?
            </div>
            
            <ul class="_pi_answers_container">
              <li>
                <a href="#">Customer service quality</a>
              </li>
              <li>
                <a href="#">Response time</a>
              </li>
              <li>
                <a href="#">Product availability</a>
              </li>
            </ul>
            
            <input
              type="text"
              class="_pi_free_text_question_field"
              placeholder="Enter your answer here..."
            />
            
            <input
              type="button"
              class="_pi_all_questions_submit_button"
              value="Submit"
            />
          </div>
        </div>
      </body>
    </html>
  `;

  return (
    <div className="survey-preview">
      <div className="preview-header">
        <h2>Preview</h2>
        <ViewportToggle />
      </div>
      
      <div
        className="preview-frame"
        style={{ width: previewWidth }}
      >
        <iframe
          srcDoc={surveyHTML}
          title="Survey Preview"
          style={{
            width: '100%',
            height: '600px',
            border: '1px solid #e5e7eb',
            borderRadius: '8px',
            backgroundColor: '#ffffff'
          }}
        />
      </div>
    </div>
  );
}
