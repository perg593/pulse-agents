/**
 * Phase 4.2: Advanced Configuration UI
 * Allows configuring template versions, rendering options, and editor options
 */

import { useState } from 'react';
import { useThemeStore } from '../stores/themeStore';
import { getTemplatesForCanvasDevice } from '../preview/templates';
import type { TemplateSelection, TemplateSelectionKey, AdvancedConfigOptions, WidgetType, QuestionType, CanvasDeviceType } from '../types/layers';

interface AdvancedConfigProps {
  onClose: () => void;
}

export function AdvancedConfig({ onClose }: AdvancedConfigProps) {
  const templateSelections = useThemeStore((state) => state.templateSelections);
  const advancedConfig = useThemeStore((state) => state.advancedConfig);
  const setTemplateSelection = useThemeStore((state) => state.setTemplateSelection);
  const updateAdvancedConfig = useThemeStore((state) => state.updateAdvancedConfig);
  
  const [localSelections, setLocalSelections] = useState<TemplateSelection[]>(templateSelections);
  const [localConfig, setLocalConfig] = useState<AdvancedConfigOptions>(advancedConfig);

  // Phase 4.2: Widget/question types (including placeholders)
  // Phase 5.0a: Added single-choice-standard and thank-you
  const widgetTypes: WidgetType[] = ['docked', 'modal'];
  const questionTypes: QuestionType[] = ['single-choice', 'single-choice-standard', 'thank-you', 'multi-choice'];

  const handleTemplateChange = (
    widgetType: WidgetType,
    questionType: QuestionType,
    deviceType: CanvasDeviceType,
    templateId: string
  ) => {
    const key: TemplateSelectionKey = { widgetType, questionType, deviceType };
    const existing = localSelections.find(
      s =>
        s.key.widgetType === widgetType &&
        s.key.questionType === questionType &&
        s.key.deviceType === deviceType
    );

    const updated: TemplateSelection = { key, templateId };

    const updatedSelections = existing
      ? localSelections.map(s =>
          s.key.widgetType === widgetType &&
          s.key.questionType === questionType &&
          s.key.deviceType === deviceType
            ? updated
            : s
        )
      : [...localSelections, updated];

    setLocalSelections(updatedSelections);
  };

  const handleRenderingOptionChange = (field: keyof AdvancedConfigOptions['rendering'], value: boolean | number) => {
    setLocalConfig({
      ...localConfig,
      rendering: {
        ...localConfig.rendering,
        [field]: value
      }
    });
  };

  const handleEditorOptionChange = (field: keyof AdvancedConfigOptions['editor'], value: boolean) => {
    setLocalConfig({
      ...localConfig,
      editor: {
        ...localConfig.editor,
        [field]: value
      }
    });
  };

  const handleSave = () => {
    // Save template selections
    localSelections.forEach(selection => {
      setTemplateSelection(selection);
    });
    
    // Save advanced config
    updateAdvancedConfig(localConfig);
    
    onClose();
  };

  const handleCancel = () => {
    setLocalSelections(templateSelections);
    setLocalConfig(advancedConfig);
    onClose();
  };

  // Helper to get available templates for a device
  const getAvailableTemplates = (
    widgetType: WidgetType,
    questionType: QuestionType,
    deviceType: CanvasDeviceType
  ) => {
    return getTemplatesForCanvasDevice(widgetType, questionType, deviceType);
  };

  // Helper to get current template ID for a combination
  const getCurrentTemplateId = (
    widgetType: WidgetType,
    questionType: QuestionType,
    deviceType: CanvasDeviceType
  ): string => {
    const selection = localSelections.find(
      s =>
        s.key.widgetType === widgetType &&
        s.key.questionType === questionType &&
        s.key.deviceType === deviceType
    );
    
    if (selection) {
      return selection.templateId;
    }
    
    // Phase 5.0a: Return default template IDs based on question type
    if (questionType === 'single-choice-standard') {
      return 'docked-single-standard-desktop-pulse-v1';
    } else if (questionType === 'thank-you') {
      return 'docked-thank-you-desktop-pulse-v1';
    } else if (deviceType === 'desktop') {
      return 'docked-single-desktop-v1';
    } else if (deviceType === 'iphone') {
      return 'docked-single-iphone-v1';
    } else {
      return 'docked-single-android-v1';
    }
  };

  // Check if a widget/question combination is supported
  // Phase 5.0a: Added support for single-choice-standard and thank-you
  const isSupported = (widgetType: WidgetType, questionType: QuestionType): boolean => {
    if (widgetType !== 'docked') return false;
    return questionType === 'single-choice' || 
           questionType === 'single-choice-standard' || 
           questionType === 'thank-you';
  };

  return (
    <div className="advanced-config-overlay" onClick={onClose}>
      <div className="advanced-config-modal" onClick={(e) => e.stopPropagation()}>
        <div className="advanced-config-header">
          <div>
            <h2>Advanced Configuration</h2>
            <p className="config-subtitle">Configure advanced settings for your widgets and templates.</p>
          </div>
          <button type="button" className="close-button" onClick={onClose}>
            ×
          </button>
        </div>
        
        <div className="advanced-config-content">
          {/* A. Template Version Matrix */}
          <div className="config-section">
            <h3 className="config-section-title">Template Version Matrix</h3>
            <table className="template-selection-table">
              <thead>
                <tr>
                  <th>Widget Type</th>
                  <th>Question Type</th>
                  <th>Desktop Template</th>
                  <th>Mobile Template</th>
                </tr>
              </thead>
              <tbody>
                {widgetTypes.map(widgetType =>
                  questionTypes.map(questionType => {
                    const supported = isSupported(widgetType, questionType);
                    const desktopTemplates = getAvailableTemplates(widgetType, questionType, 'desktop');
                    const mobileTemplates = getAvailableTemplates(widgetType, questionType, 'iphone'); // iPhone represents mobile

                    return (
                      <tr key={`${widgetType}-${questionType}`} className={supported ? '' : 'placeholder-row'}>
                        <td>{widgetType}</td>
                        <td>{questionType}</td>
                        <td>
                          {supported ? (
                            <select
                              value={getCurrentTemplateId(widgetType, questionType, 'desktop')}
                              onChange={(e) =>
                                handleTemplateChange(widgetType, questionType, 'desktop', e.target.value)
                              }
                            >
                              {desktopTemplates.map(template => (
                                <option key={template.id} value={template.id}>
                                  {template.label}
                                </option>
                              ))}
                            </select>
                          ) : (
                            <span className="placeholder-text">Coming soon</span>
                          )}
                        </td>
                        <td>
                          {supported ? (
                            <select
                              value={getCurrentTemplateId(widgetType, questionType, 'iphone')}
                              onChange={(e) =>
                                handleTemplateChange(widgetType, questionType, 'iphone', e.target.value)
                              }
                            >
                              {mobileTemplates.map(template => (
                                <option key={template.id} value={template.id}>
                                  {template.label}
                                </option>
                              ))}
                            </select>
                          ) : (
                            <span className="placeholder-text">Coming soon</span>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>

          {/* B. Rendering Options */}
          <div className="config-section">
            <h3 className="config-section-title">Rendering Options</h3>
            <div className="config-options-group">
              <label className="config-option">
                <input
                  type="checkbox"
                  checked={localConfig.rendering.enableAnimations}
                  onChange={(e) => handleRenderingOptionChange('enableAnimations', e.target.checked)}
                />
                <span>Enable Animations</span>
                <span className="option-description">Controls whether preview animations (e.g., slide-in, fades) are used.</span>
              </label>
              
              <label className="config-option">
                <input
                  type="checkbox"
                  checked={localConfig.rendering.cacheTemplates}
                  onChange={(e) => handleRenderingOptionChange('cacheTemplates', e.target.checked)}
                />
                <span>Cache Templates</span>
                <span className="option-description">Store template versions locally for faster loading.</span>
              </label>
              
              <label className="config-option">
                <span>Max Cache Size (MB)</span>
                <input
                  type="number"
                  min="1"
                  max="500"
                  value={localConfig.rendering.maxCacheSizeMB}
                  onChange={(e) => handleRenderingOptionChange('maxCacheSizeMB', parseInt(e.target.value) || 50)}
                  className="config-number-input"
                />
              </label>
            </div>
          </div>

          {/* C. Editor Options */}
          <div className="config-section">
            <h3 className="config-section-title">Editor Options</h3>
            <div className="config-options-group">
              <label className="config-option">
                <input
                  type="checkbox"
                  checked={localConfig.editor.autoSaveChanges}
                  onChange={(e) => handleEditorOptionChange('autoSaveChanges', e.target.checked)}
                />
                <span>Auto-save Changes</span>
                <span className="option-description">Automatically save theme changes as you edit.</span>
              </label>
              
              <label className="config-option">
                <input
                  type="checkbox"
                  checked={localConfig.editor.debugMode}
                  onChange={(e) => handleEditorOptionChange('debugMode', e.target.checked)}
                />
                <span>Debug Mode</span>
                <span className="option-description">Show extra console logging and debug overlays in Canvas.</span>
              </label>
            </div>
          </div>
        </div>
        
        <div className="advanced-config-footer">
          <button type="button" className="btn-secondary" onClick={handleCancel}>
            Cancel
          </button>
          <button type="button" className="btn-primary" onClick={handleSave}>
            Save
          </button>
        </div>
      </div>
    </div>
  );
}
