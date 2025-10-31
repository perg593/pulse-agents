import React from 'react';
import PropTypes from 'prop-types';

import SidebarTab from '../survey_edit_sidebar/SidebarTab';

import ExpandSidebarIcon from '../../images/survey_dashboard/expand.svg';
import CollapseSidebarIcon from '../../images/survey_dashboard/collapse.svg';

import FilteringOptions from './FilteringOptions';
import SchedulingOptions from './SchedulingOptions.jsx';
import SurveyRecommendations from './SurveyRecommendations';
import AIReadout from './ai_readout/AIReadout';

import {getDateRangeFromQueryParams} from '../CalendarContainer';

import {FilterGenie} from './FilterGenie';
import {CompletionUrlFilter} from './filtering_options/CompletionUrlFilter';
import {PageviewCountFilter} from './filtering_options/PageviewCountFilter';
import {VisitCountFilter} from './filtering_options/VisitCountFilter';

/*
 * A collapsible sidebar for survey report filters
*/
const ReportFilterSidebar = (props) => {
  const [sidebarPanelExpanded, setSidebarPanelExpanded] = React.useState(true);

  const [
    panelExpansionSettings, setPanelExpansionSettings,
  ] = React.useState({});

  const defaultFilterValues = {
    deviceFilters: ['desktop', 'tablet', 'mobile'],
    dateRangeFilters: null,
    marketFilters: props.availableMarkets ? props.availableMarkets.map((market) => market.id) : [],
    completionUrlFilters: [],
    pageviewCountFilter: null,
    visitCountFilter: null,
  };

  /**
   * Builds filters from query parameters
   * @return { object } A hash of filter selections
   **/
  function getFiltersFromQueryParams() {
    const url = new URL(window.location);
    const activeDeviceFilters = url.searchParams.getAll('device_types[]');
    const activeMarketFilters = url.searchParams.getAll('market_ids[]').
        map((market) => Number.parseInt(market));
    const activeCompletionUrlFilters = url.searchParams.getAll('completion_urls[]').map((filter) => {
      const filterParams= JSON.parse(filter);
      return new CompletionUrlFilter(
          filterParams.id,
          filterParams.matcher,
          filterParams.value,
          filterParams.cumulative,
      );
    });

    let activePageviewCountFilter = null;
    let filterParams = url.searchParams.get('pageview_count');

    if (filterParams) {
      filterParams = JSON.parse(filterParams);

      activePageviewCountFilter = new PageviewCountFilter(
          filterParams.comparator,
          filterParams.value,
      );
    }

    let activeVisitCountFilter = null;
    filterParams = url.searchParams.get('visit_count');

    if (filterParams) {
      filterParams = JSON.parse(filterParams);

      activeVisitCountFilter = new VisitCountFilter(
          filterParams.comparator,
          filterParams.value,
      );
    }

    const deviceFilters = activeDeviceFilters.length ? activeDeviceFilters :
      defaultFilterValues.deviceFilters;

    let marketFilters = [];
    if (activeMarketFilters.length) {
      marketFilters = activeMarketFilters;
    } else if (props.availableMarkets) {
      marketFilters = defaultFilterValues.marketFilters;
    }

    const completionUrlFilters = activeCompletionUrlFilters.length ? activeCompletionUrlFilters : defaultFilterValues.completionUrlFilters;

    const pageviewCountFilter = activePageviewCountFilter ? activePageviewCountFilter : defaultFilterValues.pageviewCountFilter;
    const visitCountFilter = activeVisitCountFilter ? activeVisitCountFilter : defaultFilterValues.visitCountFilter;

    const initialFilterSelection = {
      deviceFilters: deviceFilters,
      dateRangeFilters: getDateRangeFromQueryParams(url),
      marketFilters: marketFilters,
      completionUrlFilters: completionUrlFilters,
      pageviewCountFilter: pageviewCountFilter,
      visitCountFilter: visitCountFilter,
    };

    return initialFilterSelection;
  }

  const [filters, setFilters] = React.useState(() => {
    const initialFilterSelection = getFiltersFromQueryParams();

    return {
      selections: {
        ...initialFilterSelection,
      },
      defaults: {
        ...defaultFilterValues,
      },
      initial: {
        ...initialFilterSelection,
      },
    };
  });

  // [filters, scheduling, insights]
  const [openTabName, setOpenTabName] = React.useState('filters');
  const [selectedPromptVersion, setSelectedPromptVersion] = React.useState('');

  const updateSelectedFilters = (key, newValues) => {
    const newFilters = {
      ...filters.selections,
    };

    newFilters[key] = newValues;

    setFilters(
        {
          ...filters,
          selections: newFilters,
        },
    );
  };

  const onTabClick = (tabName) => {
    setOpenTabName(tabName);
  };

  const expansionClass = sidebarPanelExpanded ? 'expanded' : 'collapsed';

  const updatePanelExpansionSettings = (panelSetting) => {
    setPanelExpansionSettings({
      ...panelExpansionSettings,
      ...panelSetting,
    });
  };

  const Tabs = () => {
    switch (openTabName) {
      case 'filters':
        return (
          <FilteringOptions
            panelExpansionSettings={panelExpansionSettings}
            updatePanelExpansionSettings={updatePanelExpansionSettings}
            updateSelectedFilters={updateSelectedFilters}
            filterGenie={new FilterGenie(filters, props.availableMarkets)}
            availableMarkets={props.availableMarkets}
            completionUrlMatchers={props.completionUrlMatchers}
            comparators={props.comparators}
          />
        );
      case 'scheduling':
        return (
          <SchedulingOptions
            scheduledReportLinks={props.scheduledReportLinks}
            panelExpansionSettings={panelExpansionSettings}
            updatePanelExpansionSettings={updatePanelExpansionSettings}
          />
        );
      case 'insights':
        return (
          <>
            <AIReadout
              surveyId={props.surveyId}
              authenticityToken={props.authenticityToken}
              answerCount={props.answerCount}
              aiReadoutFeatures={props.aiReadoutFeatures}
              panelExpansionSettings={panelExpansionSettings}
              updatePanelExpansionSettings={updatePanelExpansionSettings}
              selectedPromptVersion={selectedPromptVersion}
              setSelectedPromptVersion={setSelectedPromptVersion}
              promptTemplates={props.promptTemplates || []}
              initialPromptVersion={props.initialPromptVersion}
              initialPromptText={props.initialPromptText}
              currentAiOutlineJob={props.currentAiOutlineJob}
            />
            <SurveyRecommendations
              surveyId={props.surveyId}
              authenticityToken={props.authenticityToken}
              answerCount={props.answerCount}
              panelExpansionSettings={panelExpansionSettings}
              updatePanelExpansionSettings={updatePanelExpansionSettings}
            />
          </>
        );
      default:
        console.debug('unrecognized tab name', openTabName);
        return null;
    }
  };

  return (
    <>
      {
        sidebarPanelExpanded ? <div className='sidebar-placeholder'></div> :
          null
      }
      <div className={`survey-settings-sidebar ${expansionClass}`}>
        <div
          className={`sidebar-tab ${expansionClass}`}
          onClick={() => {
            setSidebarPanelExpanded(!sidebarPanelExpanded);
          }}
        >
          <img
            className="folding-arrow-icon"
            src={sidebarPanelExpanded ? CollapseSidebarIcon : ExpandSidebarIcon}
          >
          </img>
        </div>
        <div className='sidebar-body'>
          <ul className='sidebar-tab-container'>
            <SidebarTab
              tabName='filters'
              tabLabel='Filters'
              openTabName={openTabName}
              onTabClick={() => onTabClick('filters')}
            />
            <SidebarTab
              tabName='scheduling'
              tabLabel='Scheduling'
              openTabName={openTabName}
              onTabClick={() => onTabClick('scheduling')}
            />
            {
              props.nextInsightsEnabled ? 
                <SidebarTab
                  tabName='insights'
                  tabLabel='Insights'
                  openTabName={openTabName}
                  onTabClick={() => onTabClick('insights')}
                /> : null
            }
          </ul>
          <div className='sidebar-content'>
            <Tabs />
          </div>
        </div>
      </div>
    </>
  );
};

ReportFilterSidebar.propTypes = {
  availableMarkets: PropTypes.array,
  completionUrlMatchers: PropTypes.array,
  comparators: PropTypes.array,
  scheduledReportLinks: PropTypes.object,
  surveyId: PropTypes.number,
  authenticityToken: PropTypes.string,
  answerCount: PropTypes.number,
  nextInsightsEnabled: PropTypes.bool,
  isSuperAdmin: PropTypes.bool,
};

export default ReportFilterSidebar;
