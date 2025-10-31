import React from 'react';
import PropTypes from 'prop-types';

import PanelTemplate from './PanelTemplate.jsx';

const SurveyLocaleGroupCheckbox = (props) => {
  const surveyLocaleGroupId = props.surveyLocaleGroupOption.surveyLocaleGroupId;
  const savedInDb = props.surveyLocaleGroupOption.id != null;
  const someChecked = props.checkedStates.some((surveyChecked) => {
    return surveyChecked;
  });
  const someNotChecked = props.checkedStates.some((surveyChecked) => {
    return !surveyChecked;
  });

  const expansionClass = `expand-survey-list ${props.expanded ? 'expanded' : ''}`;
  const inputId = `scheduled_report_survey_locale_group_${surveyLocaleGroupId}`;

  return (
    <div className='survey-locale-group-label-container'>
      <button
        type='button'
        className={expansionClass}
        onClick={() => {
          props.toggleExpansionState(surveyLocaleGroupId);
        }}
      >
      </button>
      <input
        id={inputId}
        type="checkbox"
        name={`${props.groupContext}[locale_group_id]`}
        value={surveyLocaleGroupId}
        default={props.surveyLocaleGroupOption.initiallyChecked}
        className={someChecked && someNotChecked ? 'partially-selected' : ''}
        onChange={(e) => {
          props.toggleSurveyLocaleGroupCheckbox(surveyLocaleGroupId);
        }}
        checked={someChecked}
      />

      {
        savedInDb ?
          <input
            type="hidden"
            name={`${props.groupContext}[id]`}
            value={props.surveyLocaleGroupOption.id}
          />: null
      }

      {
        savedInDb && !someChecked ?
          <input
            type="hidden"
            name={`${props.groupContext}[_destroy]`}
            value='1'
          />: null
      }

      <label htmlFor={inputId}>
        {props.surveyLocaleGroupOption.label}
      </label>
    </div>
  );
};

SurveyLocaleGroupCheckbox.propTypes = {
  surveyLocaleGroupOption: PropTypes.object.isRequired,
  expanded: PropTypes.bool.isRequired,
  groupContext: PropTypes.string.isRequired,
  toggleSurveyLocaleGroupCheckbox: PropTypes.func.isRequired,
  toggleExpansionState: PropTypes.func.isRequired,
  checkedStates: PropTypes.array.isRequired,
};

const SurveyCheckbox = (props) => {
  const id = `scheduled_report_survey_${props.survey.label}`;
  const name = `${props.context}[survey_id]`;
  const savedInDb = props.survey.scheduledReportSurveyId;

  return (
    <li>
      <input
        id={id}
        type="checkbox"
        name={name}
        value={props.survey.surveyId}
        checked={props.checked}
        onChange={props.onChange}
      />

      {
        savedInDb ?
          <input
            type="hidden"
            name={`${props.context}[id]`}
            value={props.survey.scheduledReportSurveyId}
          />: null
      }

      {
        savedInDb && !props.checked ?
          <input
            type="hidden"
            name={`${props.context}[_destroy]`}
            value='1'
          />: null
      }

      <label htmlFor={id}>
        {props.survey.label}
      </label>
    </li>
  );
};

SurveyCheckbox.propTypes = {
  survey: PropTypes.object.isRequired,
  context: PropTypes.string.isRequired,
  onChange: PropTypes.func,
  checked: PropTypes.bool,
};

const SurveyLocaleGroupSurveyList = (props) => {
  return (
    <ul className={props.listClass}>
      {
        props.surveys.map((survey, surveyIndex) => {
          const context = `${props.groupContext}[scheduled_report_surveys_attributes][${surveyIndex}]`;

          return (
            <SurveyCheckbox
              key={survey.label}
              survey={survey}
              context={context}
              checked={props.checkedStates[surveyIndex]}
              onChange={(e) => {
                props.updateSurveyCheckedState(surveyIndex, e.target.checked);
              }}
            />
          );
        })
      }
    </ul>
  );
};

SurveyLocaleGroupSurveyList.propTypes = {
  listClass: PropTypes.string.isRequired,
  surveys: PropTypes.array.isRequired,
  groupContext: PropTypes.string.isRequired,
  checkedStates: PropTypes.array.isRequired,
  updateSurveyCheckedState: PropTypes.func.isRequired,
};

const SurveyList = (props) => {
  return (
    <ul className='survey-list'>
      {
        props.surveyOptions.map((survey, i) => {
          const context = `scheduled_report[scheduled_report_surveys_attributes][${i}]`;

          return (
            <SurveyCheckbox
              key={survey.label}
              survey={survey}
              context={context}
              checked={props.checkedStates[survey.surveyId]}
              onChange={(e) => {
                props.updateSurveyCheckedState(survey.surveyId, e.target.checked);
              }}
            />
          );
        })
      }
    </ul>
  );
};

SurveyList.propTypes = {
  surveyOptions: PropTypes.array.isRequired,
  updateSurveyCheckedState: PropTypes.func.isRequired,
  checkedStates: PropTypes.object.isRequired,
};

const SurveyLocaleGroupList = (props) => {
  return (
    <ul>
      {
        props.surveyLocaleGroupOptions.map((surveyLocaleGroupOption, surveyLocaleGroupOptionIndex) => {
          const groupContext = `scheduled_report[scheduled_report_survey_locale_groups_attributes][${surveyLocaleGroupOptionIndex}]`;
          const surveyLocaleGroupId = surveyLocaleGroupOption.surveyLocaleGroupId;

          const sublistClass = () => {
            const hidden = props.expandedStates[surveyLocaleGroupId] === false;
            return `survey-locale-group-sub-list ${hidden ? 'hidden' : ''}`;
          };

          return (
            <li key={surveyLocaleGroupId}>
              <SurveyLocaleGroupCheckbox
                surveyLocaleGroupOption={surveyLocaleGroupOption}
                expanded={props.expandedStates[surveyLocaleGroupId]}
                toggleExpansionState={
                  (surveyLocaleGroupId) => {
                    const newVal = {...props.expandedStates};
                    newVal[surveyLocaleGroupId] = !newVal[surveyLocaleGroupId];
                    props.setExpandedStates(newVal);
                  }
                }
                checkedStates={props.checkedStates[surveyLocaleGroupId]}
                groupContext={groupContext}
                toggleSurveyLocaleGroupCheckbox={props.toggleSurveyLocaleGroupCheckbox}
              />
              <SurveyLocaleGroupSurveyList
                listClass={sublistClass()}
                surveys={surveyLocaleGroupOption.surveys}
                groupContext={groupContext}
                checkedStates={props.checkedStates[surveyLocaleGroupId]}
                updateSurveyCheckedState={(surveyIndex, newValue) => {
                  const newVal = {...props.checkedStates};
                  newVal[surveyLocaleGroupId][surveyIndex] = newValue;
                  props.setCheckedStates(newVal);
                }}
              />
            </li>
          );
        })
      }
    </ul>
  );
};

SurveyLocaleGroupList.propTypes = {
  surveyLocaleGroupOptions: PropTypes.array,
  checkedStates: PropTypes.object.isRequired,
  setCheckedStates: PropTypes.func.isRequired,
  expandedStates: PropTypes.object.isRequired,
  setExpandedStates: PropTypes.func.isRequired,
  toggleSurveyLocaleGroupCheckbox: PropTypes.func.isRequired,
};

/**
 * Renders a list of surveys and survey locale groups
 * @param {object} props - see PropTypes
 * @return {JSX.Element}
 */
function SurveyListPanel(props) {
  const [allChecked, setAllChecked] = React.useState(props.allSurveys);
  const [checkedStates, setCheckedStates] = React.useState(() => {
    const result = {};

    props.surveyLocaleGroupOptions.forEach((surveyLocaleGroupOption) => {
      result[surveyLocaleGroupOption.surveyLocaleGroupId] = surveyLocaleGroupOption.surveys.map((survey) => survey.initiallyChecked);
    });

    return result;
  });

  const [
    individualSurveyCheckedStates,
    setIndividualSurveyCheckedStates,
  ] = React.useState(() => {
    const result = {};

    props.surveyOptions.forEach((surveyOption) => {
      result[surveyOption.surveyId] = surveyOption.initiallyChecked;
    });

    return result;
  });

  const [expandedStates, setExpandedStates] = React.useState(() => {
    const result = {};

    props.surveyLocaleGroupOptions.forEach((surveyLocaleGroupOption) => {
      result[surveyLocaleGroupOption.surveyLocaleGroupId] = true;
    });

    return result;
  });

  React.useEffect(() => {
    const selectAllNode = document.getElementById('select_all_surveys');

    const someChecked = allChecked ||
      Object.values(individualSurveyCheckedStates).includes(true) ||
      Object.values(checkedStates).flat().includes(true);

    if (!someChecked) {
      selectAllNode.setCustomValidity('Please check at least one box if you want to proceed!');
    } else {
      selectAllNode.setCustomValidity('');
    }
  }, [allChecked, individualSurveyCheckedStates, checkedStates]);

  /**
   * Toggle the top-level checkbox for a survey locale group
   *  If becomes checked --> check all children
   *  If becomes unchecked --> uncheck all children
   *  If partially checked --> uncheck all children
   *
   * @param {number} surveyLocaleGroupId
   */
  function toggleSurveyLocaleGroupCheckbox(surveyLocaleGroupId) {
    let surveyCheckedStates = checkedStates[surveyLocaleGroupId];

    const someChecked = surveyCheckedStates.some((surveyChecked) => surveyChecked);
    surveyCheckedStates = Array(surveyCheckedStates.length).fill(!someChecked);

    const newStates = {...checkedStates};
    newStates[surveyLocaleGroupId] = surveyCheckedStates;

    setCheckedStates(newStates);
  }

  const renderSurveys = () => {
    if (allChecked) {
      return null;
    }

    const updateSurveyCheckedState = (surveyId, newValue) => {
      const newCheckedStates = {...individualSurveyCheckedStates};
      newCheckedStates[surveyId] = newValue;
      setIndividualSurveyCheckedStates(newCheckedStates);
    };

    return (
      <SurveyList
        surveyOptions={props.surveyOptions}
        updateSurveyCheckedState={updateSurveyCheckedState}
        checkedStates={individualSurveyCheckedStates}
      />
    );
  };

  const renderSurveyLocaleGroups = () => {
    if (allChecked) {
      return null;
    }

    return (
      <SurveyLocaleGroupList
        surveyLocaleGroupOptions={props.surveyLocaleGroupOptions}
        checkedStates={checkedStates}
        setCheckedStates={setCheckedStates}
        expandedStates={expandedStates}
        setExpandedStates={setExpandedStates}
        toggleSurveyLocaleGroupCheckbox={toggleSurveyLocaleGroupCheckbox}
      />
    );
  };

  return (
    <PanelTemplate title='Surveys'>
      <ul>
        <li>
          <input
            type="hidden"
            name='scheduled_report[all_surveys]'
            value='false'
          />
          <input
            id='select_all_surveys'
            type="checkbox"
            name='scheduled_report[all_surveys]'
            onChange={(e) => {
              setAllChecked(e.target.checked);
            }}
            checked={allChecked}
          />
          <label htmlFor='select_all_surveys'>All</label>
        </li>
      </ul>

      { renderSurveyLocaleGroups() }
      { renderSurveys() }
    </PanelTemplate>
  );
};

SurveyListPanel.propTypes = {
  allSurveys: PropTypes.bool.isRequired,
  surveyLocaleGroupOptions: PropTypes.array.isRequired, // see SurveyListPanel
  surveyOptions: PropTypes.array.isRequired, // see SurveyListPanel
};

export default SurveyListPanel;
