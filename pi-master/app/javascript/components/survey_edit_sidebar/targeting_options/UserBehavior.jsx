import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation} from '../../NumberValidations';

import CollapsiblePanel from '../../CollapsiblePanel';
import OptionsForSelect from '../../OptionsForSelect';

UserBehavior.propTypes = {
  pageviewTrigger: PropTypes.object.isRequired,

  visitTrigger: PropTypes.object.isRequired,
  visitTriggerOptions: PropTypes.object.isRequired,

  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Render User Behavior settings panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function UserBehavior(props) {
  return (
    <CollapsiblePanel
      panelTitle='User Behavior'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
    >
      <div className='sidebar-option-row option-with-description-container'>
        <div className='description-container'>
          <div className='description'>
            <span>Session Depth: require at least</span>
          </div>
          <div className='options'>
            <NumberFormat
              id='pageviews_count_field'
              className='number-input'
              value={props.pageviewTrigger.pageviewsCount || 0}
              allowNegative={false}
              decimalSeparator={null}
              onBlur={(e) => {
                props.updateFunction(
                    {
                      pageviewTrigger: {
                        ...props.pageviewTrigger,
                        pageviewsCount: e.target.value,
                      },
                    },
                );
              }}
              isAllowed={(values) => {
                return minValidation(values, 0);
              }}
            />
            <span>
              pageviews in current session
            </span>
          </div>
        </div>
      </div>
      <div className='sidebar-option-row'>
        <div className='sidebar-option-row horizontal'>
          <span>Visits:</span>
        </div>
        <div className='sidebar-option-row horizontal'>
          <select
            className='trigger-option-field'
            value={props.visitTrigger.visitorType}
            onChange={(e) => {
              props.updateFunction(
                  {
                    visitTrigger: {
                      ...props.visitTrigger,
                      visitorType: e.target.value,
                    },
                  },
              );
            }}
          >
            <OptionsForSelect
              options={props.visitTriggerOptions.visitorTypeOptions}
            />
          </select>
        </div>
        {
          props.visitTrigger.visitorType === 'repeat_visitors' ?
            <>
              <div className='sidebar-option-row horizontal'>
                <span>with at least</span>
                <NumberFormat
                  className='number-input'
                  value={props.visitTrigger.visitsCount || 0}
                  allowNegative={false}
                  decimalSeparator={null}
                  onBlur={(e) => {
                    props.updateFunction(
                        {
                          visitTrigger: {
                            ...props.visitTrigger,
                            visitsCount: e.target.value,
                          },
                        },
                    );
                  }}
                  isAllowed={(values) => {
                    return minValidation(values, 0);
                  }}
                />
                <span>previous visits</span>
              </div>
            </>: null
        }
      </div>
    </CollapsiblePanel>
  );
}

export default UserBehavior;
