import React from 'react';
import PropTypes from 'prop-types';

import ArrowUp from '../images/survey_dashboard/arrow_up.svg';
import ArrowDown from '../images/survey_dashboard/arrow_down.svg';
import ExpandLocalizationImage from '../images/survey_dashboard/folder.svg';
import CollapseLocalizationImage from '../images/survey_dashboard/overlapping_rectangles.svg';

import ExpandSidebarIcon from '../images/survey_dashboard/expand.svg';
import CollapseSidebarIcon from '../images/survey_dashboard/collapse.svg';

import MagnifyingGlass from '../images/survey_dashboard/magnifying_glass.svg';

SurveyListSidebar.propTypes = {
  surveyListData: PropTypes.array.isRequired,
};

/**
 * A wrapper component for the survey edit page's left survey list sidebar
 * @param { Object } props
 * @return { SurveyListSidebar }
*/
function SurveyListSidebar(props) {
  const [sidebarPanelExpanded, setSidebarPanelExpanded] = React.useState(false);
  const [filterText, setFilterText] = React.useState('');

  // TODO: Be more efficient
  const filterListData = (data) => {
    if (filterText.trim().length === 0) {
      return data;
    }

    const caseInsensitiveSearch = (text) => {
      const textToScan = text.toString().toLowerCase();
      const textToFind = filterText.toString().toLowerCase();

      return textToScan.includes(textToFind);
    };

    const containsSearchTerm = (listItem) => {
      return listItem.searchableContent.some(caseInsensitiveSearch);
    };

    return data.filter((listItem) => {
      if (containsSearchTerm(listItem)) {
        return true;
      } else if (listItem.type === 'surveyLocaleGroup') {
        return listItem.surveys.some((survey) => containsSearchTerm(survey));
      } else {
        return false;
      }
    });
  };

  const SurveyLine = ({survey, extraClass}) => {
    return (
      <li className={`survey-list-item ${extraClass ? extraClass : ''}`}>
        <a className='survey-link' href={survey.url} title={survey.name}>
          {
            survey.name.length > 25 ?
              `${survey.name.substring(0, 25)}...` :
                survey.name
          }
        </a>
      </li>
    );
  };
  SurveyLine.propTypes = {
    survey: PropTypes.object.isRequired,
    extraClass: PropTypes.string,
  };

  const SurveyLocaleGroupLine = ({surveyLocaleGroup}) => {
    const [groupExpanded, setGroupExpanded] = React.useState(false);

    return (
      <li className='survey-locale-group-container'>
        <ul className='survey-locale-group-list'>
          <li
            className='survey-locale-group-list-header-item'
            onClick={() => setGroupExpanded(!groupExpanded)}
          >
            <span title={surveyLocaleGroup.name}>
              {
                surveyLocaleGroup.name.length > 25 ?
                  `${surveyLocaleGroup.name.substring(0, 25)}...` :
                  surveyLocaleGroup.name
              }
            </span>
            <div>
              <img
                className="folding-folder-icon"
                src={ groupExpanded ? CollapseLocalizationImage : ExpandLocalizationImage }
              />
              <img
                className="folding-arrow-icon"
                src={ groupExpanded ? ArrowUp : ArrowDown }
              />
            </div>
          </li>
          {
            groupExpanded ?
              filterListData(surveyLocaleGroup.surveys).map((survey) => {
                return (
                  <SurveyLine
                    key={`survey_${survey.id}`}
                    survey={survey}
                    extraClass='survey-locale-group-item'
                  />
                );
              }) :
              null
          }
        </ul>
      </li>
    );
  };
  SurveyLocaleGroupLine.propTypes = {
    surveyLocaleGroup: PropTypes.object.isRequired,
  };

  return (
    <div className={`survey-list-sidebar ${sidebarPanelExpanded ? 'expanded' : 'collapsed'}`}>
      <div
        className={`sidebar-tab ${sidebarPanelExpanded ? 'expanded' : 'collapsed'} left-side`}
        onClick={() => {
          setSidebarPanelExpanded(!sidebarPanelExpanded);
        }}
      >
        <img
          className="folding-arrow-icon"
          src={sidebarPanelExpanded ? CollapseSidebarIcon : ExpandSidebarIcon}>
        </img>
      </div>

      <div className='sidebar-body'>
        <div className='sidebar-search-container'>
          <input
            className='sidebar-search-field'
            onChange={(e) => setFilterText(e.target.value)}
            placeholder='Search Names & Content'
          />
          <img className="magnifying-glass-icon" src={ MagnifyingGlass }>
          </img>
        </div>

        <ul className='sidebar-list'>
          {
            filterListData(props.surveyListData).map((listItem) => {
              return (
                listItem.type === 'survey' ?
                  <SurveyLine
                    key={`survey_${listItem.id}`}
                    survey={listItem}
                  /> :
                    <SurveyLocaleGroupLine
                      key={`survey_locale_group_${listItem.id}`}
                      surveyLocaleGroup={listItem}
                    />
              );
            })
          }
        </ul>
      </div>
    </div>
  );
}

export default SurveyListSidebar;
