import React from 'react';
import PropTypes from 'prop-types';

import PiModal from '../modal_dialog/PiModal';

import DisabledFeaturesContext from '../survey_editor/DisabledFeaturesContext';
import CollapsiblePanel from '../CollapsiblePanel';
import WidgetTypeOptions from '../survey_edit_sidebar/WidgetOptions.jsx';

FormattingOptions.propTypes = {
  setFormattingOptions: PropTypes.func.isRequired,
  formattingOptions: PropTypes.object.isRequired,
  toggleAllAtOnce: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Render survey formatting tab
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function FormattingOptions(props) {
  const disabledFeaturesContext = React.useContext(DisabledFeaturesContext);
  const lockQuestionOrderRandomization = disabledFeaturesContext.disableStructuralChanges || disabledFeaturesContext.readOnly;
  const lockAllAtOnceMode = disabledFeaturesContext.disableStructuralChanges || disabledFeaturesContext.readOnly;

  const updateFormattingOption = (newObject) => {
    props.setFormattingOptions({
      ...props.formattingOptions,
      ...newObject,
    });
  };

  const dialogRef = React.useRef(null);

  const openDialog = () => {
    if (dialogRef.current) {
      dialogRef.current.showModal();
    }
  };

  CssModal.propTypes = {
    children: PropTypes.node.isRequired,
  };
  /**
   * Render survey CSS modal dialog
   * @param {object} props - see propTypes
   * @return {JSX.Element}
  */
  function CssModal(props) {
    return (
      <PiModal
        ref={dialogRef}
        modalClassName='css-modal'
      >
        <PiModal.Header title='Edit CSS' titleClassName='css-modal-title' />

        <PiModal.Body>
          {props.children}
        </PiModal.Body>
      </PiModal>
    );
  }

  return (
    <>
      <WidgetTypeOptions
        updateFormattingOption={updateFormattingOption}
        formattingOptions={props.formattingOptions}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <CollapsiblePanel
        panelTitle='Question Display'
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      >
        <div className='sidebar-option-row'>
          <label
            className='sidebar-label'
            htmlFor='display_all_questions_field'
          >
            Question Display:
          </label>
          <select
            id='display_all_questions_field'
            value={props.formattingOptions.displayAllQuestions}
            disabled={lockAllAtOnceMode}
            onChange={
              (e) => {
                updateFormattingOption({displayAllQuestions: e.target.value});
                props.toggleAllAtOnce();
              }
            }
          >
            <option value={true}>
              All at once
            </option>
            <option value={false}>
              One at a time
            </option>
          </select>
        </div>

        {
          props.formattingOptions.displayAllQuestions === 'true' ?
            <>
              <div className='sidebar-option-row horizontal'>
                <input
                  id='all_at_once_empty_error_enabled_field'
                  type='checkbox'
                  onChange={(e) => {
                    updateFormattingOption({allAtOnceEmptyErrorEnabled: e.target.checked})
                  }}
                  value={props.formattingOptions.allAtOnceEmptyErrorEnabled}
                  checked={props.formattingOptions.allAtOnceEmptyErrorEnabled}
                />
                <label
                  className='sidebar-label'
                  htmlFor='all_at_once_empty_error_enabled_field'
                >
                  Enable empty error
                </label>
              </div>

              <div className='sidebar-option-row'>
                <label
                  className='sidebar-label'
                  htmlFor='all_at_once_submit_label_field'
                >
                  Submit Button Text
                </label>
                <input
                  id='all_at_once_submit_label_field'
                  defaultValue={props.formattingOptions.allAtOnceSubmitLabel}
                  onBlur={(e) => updateFormattingOption({allAtOnceSubmitLabel: e.target.value})}
                />
              </div>

              <div className='sidebar-option-row'>
                <label
                  className='sidebar-label'
                  htmlFor='all_at_once_error_text_field'
                >
                  Error Text
                </label>
                <input
                  id='all_at_once_error_text_field'
                  defaultValue={props.formattingOptions.allAtOnceErrorText}
                  onBlur={(e) => updateFormattingOption({
                    allAtOnceErrorText: e.target.value,
                  })}
                />
              </div>
            </> :
            null
        }

        <div className='sidebar-option-row'>
          <label
            id='randomize_question_order_field'
            className='sidebar-label'
          >
            Random Order:
          </label>
          <select
            id='randomize_question_order_field'
            value={props.formattingOptions.randomizeQuestionOrder}
            disabled={lockQuestionOrderRandomization}
            onChange={(e) => updateFormattingOption({
              randomizeQuestionOrder: e.target.value,
            })}
          >
            <option value={'true'}>
              Randomize
            </option>
            <option value={'false'}>
              Not randomized
            </option>
          </select>
        </div>
      </CollapsiblePanel>

      <CollapsiblePanel
        panelTitle='Theme'
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      >
        <div className='sidebar-option-row'>
          <label
            className='sidebar-label'
            htmlFor='theme_id_field'
          >
            Web Theme:
          </label>
          <select
            id='theme_id_field'
            value={props.formattingOptions.themeId}
            onChange={(e) => updateFormattingOption({themeId: e.target.value})}
          >
            {
              props.formattingOptions.availableCssThemes.map((theme) => {
                return (
                  <option key={theme.label} value={theme.id || ''}>
                    {theme.label}
                  </option>
                );
              })
            }
          </select>
        </div>
        <div className='sidebar-option-row'>
          <label
            className='sidebar-label'
            htmlFor='sdk_theme_id_field'
          >
            SDK Theme:
          </label>
          <select
            id='sdk_theme_id_field'
            value={props.formattingOptions.sdkThemeId}
            onChange={(e) => updateFormattingOption({
              sdkThemeId: e.target.value,
            })}
          >
            {
              props.formattingOptions.availableSdkThemes.map((theme) => {
                return (
                  <option key={theme.label} value={theme.id || ''}>
                    {theme.label}
                  </option>
                );
              })
            }
          </select>
        </div>
      </CollapsiblePanel>
      <CollapsiblePanel
        panelTitle='Survey-level Advanced Formatting'
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      >
        <input
          type='button'
          className='sidebar-button'
          onClick={openDialog}
          value='EDIT CSS'
        />
        <CssModal>
          <textarea
            rows="5"
            cols="33"
            placeholder='Enter your custom CSS'
            defaultValue={props.formattingOptions.customCss}
            onBlur={(e) => updateFormattingOption({customCss: e.target.value})}
          >
          </textarea>
        </CssModal>
      </CollapsiblePanel>
    </>
  );
}

export default FormattingOptions;
