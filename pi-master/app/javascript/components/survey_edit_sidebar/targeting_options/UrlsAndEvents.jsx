import React, {useState} from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../../CollapsiblePanel';
import DeleteButton from '../../DeleteButton';

import LocalizedSurveyIcon from '../../../images/survey_dashboard/localized_survey.svg';

import OptionsForSelect from '../../OptionsForSelect';

UrlsAndEvents.propTypes = {
  targetingOptions: PropTypes.object.isRequired,
  triggers: PropTypes.array.isRequired,
  suppressers: PropTypes.array.isRequired,
  onArrayPropertyChange: PropTypes.func.isRequired,
  deleteArrayItem: PropTypes.func.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
};

/**
 * The UrlsAndEvents sidebar panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function UrlsAndEvents(props) {
  const AddNewButton = ({propertyName}) => {
    return (
      <input
        type='button'
        className='sidebar-button new-trigger-button'
        onClick={() => {
          props.onArrayPropertyChange(null, propertyName, {
            typeCd: 'UrlTrigger',
            triggerContent: 'yoursite.com/path',
          });
        }}
        value='ADD NEW'
      />
    );
  };
  AddNewButton.propTypes = {
    propertyName: PropTypes.string.isRequired,
  };

  const Suppresser = ({index}) => {
    return (
      <BaseTrigger
        index={index}
        propertyName='suppressers'
        canDelete={true}
      />
    );
  };
  Suppresser.propTypes = {
    index: PropTypes.number.isRequired,
  };

  const Trigger = ({index, canDelete}) => {
    return (
      <BaseTrigger
        index={index}
        propertyName='triggers'
        canDelete={canDelete}
      />
    );
  };
  Trigger.propTypes = {
    index: PropTypes.number.isRequired,
    canDelete: PropTypes.bool.isRequired,
  };

  /**
   * Renders a trigger or suppresser found at the specified index
   *
   * @param { bigint } index - Index of the object to delete
   * @param { string } type - [triggers, suppressers] type to render
   *
   * @return {JSX.Element}
   */
  const BaseTrigger = ({index, propertyName, canDelete}) => {
    if (!['triggers', 'suppressers'].includes(propertyName)) {
      console.debug('unrecognized propertyName', propertyName);
    }

    const trigger = props.targetingOptions[propertyName][index];
    if (trigger.flaggedForDeletion) {
      return null;
    }

    const [triggerContent, setTriggerContent] = useState(trigger.triggerContent);
    const [typeCd, setTriggerType] = useState(trigger.typeCd);

    const fallbackValues = {
      UrlTrigger: 'yoursite.com/path',
      RegexpTrigger: '/regex/',
      UrlMatchesTrigger: 'yoursite.com/path',
      MobilePageviewTrigger: 'inlineSurveyView',
      MobileRegexpTrigger: '/regex/',
      PseudoEventTrigger: 'NAME_LANG_MARKET',
    };

    const fallbackValue = (typeCd) => {
      return fallbackValues[typeCd];
    };

    const triggerContentOrFallback = (typeCd) => {
      if (triggerContent === '' || Object.values(fallbackValues).includes(triggerContent)) {
        return fallbackValue(typeCd);
      } else {
        return triggerContent;
      }
    };

    return (
      <div className='trigger-wrapper'>
        <div className='control-wrapper'>
          <div className='sidebar-option-row url-trigger-row'>
            <select
              className='trigger-option-field'
              value={trigger.typeCd}
              onChange={(e) => {
                setTriggerType(e.target.value);
                props.onArrayPropertyChange(
                    index,
                    propertyName,
                    {
                      typeCd: e.target.value,
                      triggerContent: triggerContentOrFallback(e.target.value),
                    },
                );
              }}
            >
              <OptionsForSelect options={props.targetingOptions.triggerOptions} />
            </select>
          </div>
          <div className='sidebar-option-row horizontal url-trigger-row'>
            <img
              className="grouping-icon"
              src={LocalizedSurveyIcon}
            />
            <input
              className='url-field'
              defaultValue={trigger.triggerContent}
              title={trigger.triggerContent}
              onChange={(e) => setTriggerContent(e.target.value)}
              onBlur={(e) =>
                props.onArrayPropertyChange(
                    index,
                    propertyName,
                    {triggerContent: e.target.value.trim() || fallbackValue(typeCd)},
                )
              }
            />
          </div>
        </div>
        {
          canDelete ?
            <div className='delete-button-wrapper'>
              <DeleteButton
                onClick={(e) => props.deleteArrayItem(index, propertyName)}
              />
            </div> :
              null
        }
      </div>
    );
  };
  BaseTrigger.propTypes = {
    index: PropTypes.number.isRequired,
    propertyName: PropTypes.string.isRequired,
    canDelete: PropTypes.bool.isRequired,
  };

  return (
    <CollapsiblePanel
      panelTitle='URLs & Events'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      panelClass='urls-and-events-panel'
      expandByDefault
    >
      <div className='sidebar-label'>
        Display if:
      </div>

      {
        props.triggers.map((_trigger, i) => {
          return (
            <Trigger
              key={i}
              index={i}
              canDelete={
                props.triggers.filter((trigger) => {
                  return !trigger.flaggedForDeletion;
                }).length > 1
              }
            />
          );
        })
      }

      <AddNewButton propertyName='triggers' />

      <div className='sidebar-label'>
        Suppress if:
      </div>
      {
        props.suppressers.map((_suppresser, i) => {
          return <Suppresser key={i} index={i} />;
        })
      }
      <AddNewButton propertyName='suppressers' />
    </CollapsiblePanel>
  );
}

export default UrlsAndEvents;
