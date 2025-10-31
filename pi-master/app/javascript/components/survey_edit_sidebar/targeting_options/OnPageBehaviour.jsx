import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation, maxValidation} from '../../NumberValidations';

import CollapsiblePanel from '../../CollapsiblePanel';
import OptionsForSelect from '../../OptionsForSelect';

OnPageBehaviour.propTypes = {
  pageAfterSecondsTrigger: PropTypes.object.isRequired,
  pageScrollTrigger: PropTypes.object.isRequired,
  pageIntentExitTrigger: PropTypes.object.isRequired,
  pageElementClickedTrigger: PropTypes.object.isRequired,
  pageElementVisibleTrigger: PropTypes.object.isRequired,
  textOnPageTrigger: PropTypes.object.isRequired,
  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * The OnPageBehaviour sidebar panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function OnPageBehaviour(props) {
  return (
    <CollapsiblePanel
      panelTitle='On Page Behavior'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
    >
      <div className='sidebar-option-row option-with-description-container'>
        <div className='checkbox-container'>
          <input
            type="checkbox"
            onChange={(e) => {
              props.updateFunction(
                  {
                    pageAfterSecondsTrigger: {
                      ...props.pageAfterSecondsTrigger,
                      renderAfterXSecondsEnabled: e.target.checked,
                    },
                  },
              );
            }}
            value={props.pageAfterSecondsTrigger.renderAfterXSecondsEnabled || ''}
            checked={props.pageAfterSecondsTrigger.renderAfterXSecondsEnabled}
          />
        </div>

        <div className='description-container'>
          <div className='description'>
            <span>Delay: Show after</span>
          </div>

          <div className='options'>
            <NumberFormat
              className='number-input'
              value={props.pageAfterSecondsTrigger.renderAfterXSeconds}
              isAllowed={(values) => {
                return minValidation(values, 0);
              }}
              onBlur={(e) => {
                props.updateFunction(
                    {
                      pageAfterSecondsTrigger: {
                        ...props.pageAfterSecondsTrigger,
                        renderAfterXSeconds: e.target.value,
                      },
                    },
                );
              }}
            />

            <span>seconds</span>
          </div>
        </div>
      </div>
      <div className='sidebar-option-row option-with-description-container'>
        <div className='checkbox-container'>
          <input
            type="checkbox"
            onChange={(e) => {
              props.updateFunction(
                  {
                    pageScrollTrigger: {
                      ...props.pageScrollTrigger,
                      renderAfterXPercentScrollEnabled: e.target.checked,
                    },
                  },
              );
            }}
            value={props.pageScrollTrigger.renderAfterXPercentScrollEnabled || ''}
            checked={props.pageScrollTrigger.renderAfterXPercentScrollEnabled}
          />
        </div>

        <div className='description-container'>
          <div className='description'>
            <span>Scroll: show after user scrolls</span>
          </div>

          <div className='options'>
            <NumberFormat
              className='number-input'
              value={props.pageScrollTrigger.renderAfterXPercentScroll}
              isAllowed={(values) => {
                return minValidation(values, 0) && maxValidation(values, 100);
              }}
              onBlur={(e) => {
                props.updateFunction(
                    {
                      pageScrollTrigger: {
                        ...props.pageScrollTrigger,
                        renderAfterXPercentScroll: e.target.value,
                      },
                    },
                );
              }}
            />

            <span>percent of page length</span>
          </div>
        </div>
      </div>

      <div className='sidebar-option-row option-with-description-container'>
        <div className='checkbox-container'>
          <input
            id='intent_exit_trigger_field'
            type="checkbox"
            onChange={(e) => {
              props.updateFunction(
                  {
                    pageIntentExitTrigger: {
                      ...props.pageIntentExitTrigger,
                      renderAfterIntentExitEnabled: e.target.checked,
                    },
                  },
              );
            }}
            value={props.pageIntentExitTrigger.renderAfterIntentExitEnabled || ''}
            checked={props.pageIntentExitTrigger.renderAfterIntentExitEnabled}
          />
        </div>
        <div className='description-container'>
          <div className='description'>
            <label
              className='sidebar-label'
              htmlFor='intent_exit_trigger_field'
            >
              Exit intent: show upon likely exit behavior (desktop only)
            </label>
          </div>
        </div>
      </div>
      <div className='sidebar-option-row option-with-description-container'>
        <div className='checkbox-container'>
          <input
            type="checkbox"
            onChange={(e) => {
              props.updateFunction(
                  {
                    pageElementClickedTrigger: {
                      ...props.pageElementClickedTrigger,
                      renderAfterElementClickedEnabled: e.target.checked,
                    },
                  },
              );
            }}
            value={props.pageElementClickedTrigger.renderAfterElementClickedEnabled || ''}
            checked={props.pageElementClickedTrigger.renderAfterElementClickedEnabled}
          />
        </div>
        <div className='description-container'>
          <div className='description'>
            <span>Click: show after user clicks element</span>
          </div>
          <div className='options'>
            <input
              placeholder='CSS Selector'
              defaultValue={props.pageElementClickedTrigger.renderAfterElementClicked}
              onBlur={(e) => {
                props.updateFunction(
                    {
                      pageElementClickedTrigger: {
                        ...props.pageElementClickedTrigger,
                        renderAfterElementClicked: e.target.value,
                      },
                    },
                );
              }}
            />
          </div>
        </div>
      </div>
      <div className='sidebar-option-row option-with-description-container'>
        <div className='checkbox-container'>
          <input
            type="checkbox"
            onChange={(e) => {
              props.updateFunction(
                  {
                    pageElementVisibleTrigger: {
                      ...props.pageElementVisibleTrigger,
                      renderAfterElementVisibleEnabled: e.target.checked,
                    },
                  },
              );
            }}
            value={props.pageElementVisibleTrigger.renderAfterElementVisibleEnabled || ''}
            checked={props.pageElementVisibleTrigger.renderAfterElementVisibleEnabled}
          />
        </div>
        <div className='description-container'>
          <div className='description'>
            <span>Content in view: show after element scrolls into viewport</span>
          </div>
          <div className='options'>
            <input
              placeholder='CSS Selector'
              defaultValue={props.pageElementVisibleTrigger.renderAfterElementVisible}
              onBlur={(e) => {
                props.updateFunction(
                    {
                      pageElementVisibleTrigger: {
                        ...props.pageElementVisibleTrigger,
                        renderAfterElementVisible: e.target.value,
                      },
                    },
                );
              }}
            />
          </div>
        </div>
      </div>
      <div className='sidebar-option-row option-with-description-container'>
        <div className='checkbox-container'>
          <input
            type="checkbox"
            onChange={(e) => {
              props.updateFunction(
                  {
                    textOnPageTrigger: {
                      ...props.textOnPageTrigger,
                      textOnPageEnabled: e.target.checked,
                    },
                  },
              );
            }}
            value={props.textOnPageTrigger.textOnPageEnabled || ''}
            checked={props.textOnPageTrigger.textOnPageEnabled}
          />
        </div>
        <div className='description-container'>
          <div className='description'>
            <span>Text on page: show if page element</span>
          </div>

          <div className='options'>
            <input
              placeholder='CSS Selector'
              defaultValue={props.textOnPageTrigger.textOnPageSelector}
              onBlur={(e) => {
                props.updateFunction(
                    {
                      textOnPageTrigger: {
                        ...props.textOnPageTrigger,
                        textOnPageSelector: e.target.value,
                      },
                    },
                );
              }}
            />
          </div>
          <div className='options'>
            <select
              value={props.textOnPageTrigger.textOnPagePresence || ''}
              onChange={(e) => {
                props.updateFunction(
                    {
                      textOnPageTrigger: {
                        ...props.textOnPageTrigger,
                        textOnPagePresence: e.target.value,
                      },
                    },
                );
              }}
            >
              <OptionsForSelect
                options={[
                  {label: 'contains', value: true},
                  {label: 'does not contain', value: false},
                ]}
              />
            </select>
          </div>
          <div className='options'>
            <input
              placeholder='Text'
              defaultValue={props.textOnPageTrigger.textOnPageValue}
              onBlur={(e) => {
                props.updateFunction(
                    {
                      textOnPageTrigger: {
                        ...props.textOnPageTrigger,
                        textOnPageValue: e.target.value,
                      },
                    },
                );
              }}
            />
          </div>
        </div>
      </div>
    </CollapsiblePanel>
  );
}

export default OnPageBehaviour;
