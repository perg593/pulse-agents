import type { ThemeTokensLite, ThemeProject } from '../types/theme';
import { getContrastRatio, getContrastStatus } from './contrast';

/**
 * Generates HTML style guide from theme and project
 */
export function buildStyleGuideHtml(theme: ThemeTokensLite, project: ThemeProject): string {
  const { palette, typography, components } = theme;
  
  // Calculate contrast ratios
  const textOnBgRatio = getContrastRatio(palette.textPrimary, palette.background);
  const textOnSurfaceRatio = getContrastRatio(palette.textPrimary, palette.surface);
  const ctaRatio = getContrastRatio(components.ctaButton.text, components.ctaButton.bg);
  const singleChoiceRatio = getContrastRatio(components.singleChoice.textActive, components.singleChoice.bgActive);
  
  const textOnBgStatus = getContrastStatus(textOnBgRatio);
  const textOnSurfaceStatus = getContrastStatus(textOnSurfaceRatio);
  const ctaStatus = getContrastStatus(ctaRatio);
  const singleChoiceStatus = getContrastStatus(singleChoiceRatio);
  
  // Phase 4.3: Format status message for HTML
  const formatStatusMessageHtml = (status: typeof textOnBgStatus): string => {
    if (status.status === 'fail') {
      return '⚠️ Low contrast – consider adjusting';
    }
    return '✅ Pass (AA)';
  };

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Style Guide: ${theme.name}</title>
</head>
<body>
  <section>
    <h1>Theme: ${theme.name}</h1>
    <p>Project: ${project.name}</p>
    <p>Variant: ${theme.variantType}</p>
  </section>
  
  <section>
    <h2>Color Palette</h2>
    <ul>
      <li><strong>Brand Primary</strong> (<code>palette.brandPrimary</code>): <code>${palette.brandPrimary}</code></li>
      <li><strong>Brand Secondary</strong> (<code>palette.brandSecondary</code>): <code>${palette.brandSecondary}</code></li>
      <li><strong>Accent</strong> (<code>palette.accent</code>): <code>${palette.accent}</code></li>
      <li><strong>Background</strong> (<code>palette.background</code>): <code>${palette.background}</code></li>
      <li><strong>Surface</strong> (<code>palette.surface</code>): <code>${palette.surface}</code></li>
      <li><strong>Text Primary</strong> (<code>palette.textPrimary</code>): <code>${palette.textPrimary}</code></li>
      <li><strong>Text Secondary</strong> (<code>palette.textSecondary</code>): <code>${palette.textSecondary}</code></li>
      <li><strong>Success</strong> (<code>palette.success</code>): <code>${palette.success}</code></li>
      <li><strong>Danger</strong> (<code>palette.danger</code>): <code>${palette.danger}</code></li>
    </ul>
  </section>
  
  <section>
    <h2>Typography</h2>
    <div>
      <h3>Heading</h3>
      <p><code>${typography.headingSize}px / ${typography.fontFamilyHeading || typography.fontFamilyBase} / 600</code></p>
      <p>"Quick Feedback Survey"</p>
    </div>
    <div>
      <h3>Body</h3>
      <p><code>${typography.bodySize}px / ${typography.fontFamilyBase} / 400</code></p>
      <p>"How satisfied are you with our service?"</p>
    </div>
    <div>
      <h3>Button</h3>
      <p><code>${typography.buttonSize}px / ${typography.fontFamilyBase} / 500</code></p>
      <p>"Submit Feedback"</p>
    </div>
  </section>
  
  <section>
    <h2>Components</h2>
    <ul>
      <li>Single Choice (Default + Active)</li>
      <li>CTA Button</li>
      <li>Text Input</li>
    </ul>
  </section>
  
  <section>
    <h2>Accessibility</h2>
    <ul>
      <li>Text on Background: <code>${textOnBgRatio.toFixed(2)}:1</code> – ${formatStatusMessageHtml(textOnBgStatus)}</li>
      <li>Text on Surface: <code>${textOnSurfaceRatio.toFixed(2)}:1</code> – ${formatStatusMessageHtml(textOnSurfaceStatus)}</li>
      <li>CTA Text on CTA BG: <code>${ctaRatio.toFixed(2)}:1</code> – ${formatStatusMessageHtml(ctaStatus)}</li>
      <li>Single Choice Active Text on Active BG: <code>${singleChoiceRatio.toFixed(2)}:1</code> – ${formatStatusMessageHtml(singleChoiceStatus)}</li>
    </ul>
  </section>
</body>
</html>`;
}

/**
 * Generates Markdown style guide from theme and project
 */
export function buildStyleGuideMarkdown(theme: ThemeTokensLite, project: ThemeProject): string {
  const { palette, typography, components } = theme;
  
  // Calculate contrast ratios
  const textOnBgRatio = getContrastRatio(palette.textPrimary, palette.background);
  const textOnSurfaceRatio = getContrastRatio(palette.textPrimary, palette.surface);
  const ctaRatio = getContrastRatio(components.ctaButton.text, components.ctaButton.bg);
  const singleChoiceRatio = getContrastRatio(components.singleChoice.textActive, components.singleChoice.bgActive);
  
  const textOnBgStatus = getContrastStatus(textOnBgRatio);
  const textOnSurfaceStatus = getContrastStatus(textOnSurfaceRatio);
  const ctaStatus = getContrastStatus(ctaRatio);
  const singleChoiceStatus = getContrastStatus(singleChoiceRatio);
  
  // Phase 4.3: Format status message
  const formatStatusMessage = (status: typeof textOnBgStatus): string => {
    if (status.status === 'fail') {
      return '⚠️ Low contrast – consider adjusting';
    }
    return '✅ Pass (AA)';
  };

  return `# Theme: ${theme.name}

Project: ${project.name}  
Variant: ${theme.variantType}

## Color Palette

- **Brand Primary** (\`palette.brandPrimary\`): \`${palette.brandPrimary}\`
- **Brand Secondary** (\`palette.brandSecondary\`): \`${palette.brandSecondary}\`
- **Accent** (\`palette.accent\`): \`${palette.accent}\`
- **Background** (\`palette.background\`): \`${palette.background}\`
- **Surface** (\`palette.surface\`): \`${palette.surface}\`
- **Text Primary** (\`palette.textPrimary\`): \`${palette.textPrimary}\`
- **Text Secondary** (\`palette.textSecondary\`): \`${palette.textSecondary}\`
- **Success** (\`palette.success\`): \`${palette.success}\`
- **Danger** (\`palette.danger\`): \`${palette.danger}\`

## Typography

**Heading**  
\`${typography.headingSize}px / ${typography.fontFamilyHeading || typography.fontFamilyBase} / 600\`  
"Quick Feedback Survey"

**Body**  
\`${typography.bodySize}px / ${typography.fontFamilyBase} / 400\`  
"How satisfied are you with our service?"

**Button**  
\`${typography.buttonSize}px / ${typography.fontFamilyBase} / 500\`  
"Submit Feedback"

## Components

- Single Choice (Default + Active)
- CTA Button
- Text Input

## Accessibility

- Text on Background: \`${textOnBgRatio.toFixed(2)}:1\` – ${formatStatusMessage(textOnBgStatus)}
- Text on Surface: \`${textOnSurfaceRatio.toFixed(2)}:1\` – ${formatStatusMessage(textOnSurfaceStatus)}
- CTA Text on CTA BG: \`${ctaRatio.toFixed(2)}:1\` – ${formatStatusMessage(ctaStatus)}
- Single Choice Active Text on Active BG: \`${singleChoiceRatio.toFixed(2)}:1\` – ${formatStatusMessage(singleChoiceStatus)}
`;
}

