import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';

import SurveyDashboardTable from './SurveyDashboardTable';
import {
  customDateFiltering, customORFiltering, fuzzyTextFilter,
} from './FilterFunctions';
import EditableCell from './survey_dashboard/EditableCell';

import ArrowUp from '../images/survey_dashboard/caret_open.svg';
import ArrowDown from '../images/survey_dashboard/caret_closed.svg';
import ExpandLocalizationImage from '../images/survey_dashboard/folder.svg';
import CollapseLocalizationImage from '../images/survey_dashboard/overlapping_rectangles.svg';
import IndividualSurveyIcon from '../images/survey_dashboard/individual_survey.svg';
import LocalizedSurveyIcon from '../images/survey_dashboard/localized_survey.svg';

// The icons that appear next to survey locale group names
const LocalizationIcons = ({reactTableProps: {row}}) => {
  if (row.subRows.length > 0) {
    return (
      <div
        {...row.getToggleRowExpandedProps()}
        className='folding-icon-container'
      >
        <img
          className="folding-arrow-icon"
          src={ row.isExpanded ? ArrowUp : ArrowDown }
        />
        {
          /*
           * This mask-image technique for rendering svg icons with background
           * colours does not work with img tags, for reasons I'm not clear on.
           * img would be more semantic, but it leaves a border around the mask.
           */
        }
        <div
          style={{
            maskImage: row.isExpanded ?
              `url(${CollapseLocalizationImage})` :
                `url(${ExpandLocalizationImage})`,
            WebkitMaskImage: row.isExpanded ?
              `url(${CollapseLocalizationImage})` :
                `url(${ExpandLocalizationImage})`,
          }}
          className={`folding-folder-icon ${row.isExpanded ? 'expanded' : ''} `}
        >
        </div>
      </div>
    );
  } else if (row.depth == 0) {
    return (
      <img
        className="individual-survey-icon"
        src={IndividualSurveyIcon}
      />
    );
  } else if (row.depth == 1) {
    return (
      <img
        className="localized-survey-icon"
        src={LocalizedSurveyIcon}
      />
    );
  }
};

SurveyDashboard.propTypes = {
  allowSurveyNameChange: PropTypes.bool.isRequired,
  allowSurveyStatusChange: PropTypes.bool.isRequired,
  storedFilters: PropTypes.array.isRequired,
  surveyStatusOptions: PropTypes.array.isRequired,
  surveyEditedByOptions: PropTypes.array.isRequired,
  surveyTagOptions: PropTypes.array.isRequired,
  surveyCreatedByNameOptions: PropTypes.array.isRequired,
  surveys: PropTypes.array.isRequired,
  tagsLink: PropTypes.string.isRequired,
  showChangeLogButton: PropTypes.bool.isRequired,
  cacheDetails: PropTypes.object.isRequired,
};

/**
 * A wrapper for the table, provides high-level functionality and the
 * possibility of reuse of the table component
 * @param {object} props - see PropTypes
 * @return {JSX.Element} the table
 */
function SurveyDashboard(props) {
  const [contextMenuHidden, setContextMenuHidden] = React.useState(true);
  const [contextMenuPosition, setContextMenuPosition] = React.useState([0, 0]);

  const initialCheckedState = (columnId, optionValue) => {
    if (props.storedFilters.length > 0) {
      return props.storedFilters.some((filter) => {
        if (filter.id === columnId) {
          return filter.value.includes(optionValue);
        } else {
          return false;
        }
      });
    } else {
      return columnId === 'statusID' && ['live', 'draft'].includes(optionValue);
    }
  };

  const initialTextFilter = (columnId) => {
    const filter = props.storedFilters.find((filter) => filter.id === columnId);
    return filter ? filter.value : null;
  };

  const dateSort = (rowA, rowB, id) => {
    const dateA = new Date(rowA.original[id]);
    const dateB = new Date(rowB.original[id]);

    // https://react-table.tanstack.com/docs/api/useSortBy#column-options
    // The sortType function should return 1 if rowA is larger, and -1
    // if rowB is larger. react-table will take care of the rest.
    return Math.sign(dateA - dateB);
  };

  const caseInsensitiveSort = (rowA, rowB, id) => {
    const a = rowA.original[id];
    const b = rowB.original[id];

    if (!a || !b) {
      return 0;
    }

    return a.localeCompare(b, 'en', {sensitivity: 'base'});
  };

  // Defines the columns and their default order
  const columns = React.useMemo(
      () => [
        {
          Header: 'Name',
          accessor: 'name', // accessor is the "key" in the data
          id: 'nameID',
          disableFilters: false,
          filter: fuzzyTextFilter,
          dbColumnName: 'name',
          initialFilterValue: initialTextFilter('nameID'),
          sortType: (rowA, rowB) => {
            return caseInsensitiveSort(rowA, rowB, 'name');
          },
          Cell: (params) =>
            <>
              <LocalizationIcons reactTableProps={params} />
              {
                props.allowSurveyNameChange ?
                  <EditableCell reactTableProps={params} /> :
                    <span>{params.value}</span>
              }
            </>
        },
        {
          Header: 'Status',
          accessor: 'status',
          className: 'status',
          id: 'statusID',
          disableFilters: false,
          filter: customORFiltering,
          options: props.surveyStatusOptions.map((option) => {
            return ({
              ...option,
              initialCheckedState: initialCheckedState('statusID', option.value),
            });
          }),
          dbColumnName: 'status',
          sortType: (rowA, rowB) => {
            return caseInsensitiveSort(rowA, rowB, 'status');
          },
          Cell: (params) =>
            params.row.original.type === 'survey' ?
              <EditableCell reactTableProps={params} /> : '-'
        },
        {
          Header: 'Goal',
          accessor: 'goal',
          className: 'goals',
          id: 'goalID',
          disableFilters: true,
          dbColumnName: 'goal',
          Cell: (params) =>
            params.row.original.type === 'survey' ?
              <EditableCell reactTableProps={params} /> : '-'
        },
        {
          Header: 'Impressions',
          accessor: 'impressions',
          className: 'impressions',
          id: 'impressionsID',
          disableFilters: true,
          usesCachedData: true,
          Cell: (params) =>
            <NumberFormat
              value={params.value}
              displayType={'text'}
              thousandSeparator={true}
            />,
        },
        {
          Header: 'Submissions',
          accessor: 'submissions',
          className: 'submissions',
          id: 'submissionsID',
          disableFilters: true,
          usesCachedData: true,
          Cell: (params) =>
            <NumberFormat
              value={params.value}
              displayType={'text'}
              thousandSeparator={true}
            />,
        },
        {
          Header: 'Submission Rate',
          accessor: 'submissionRate',
          className: 'rates',
          id: 'submissionRateID',
          disableFilters: true,
          usesCachedData: true,
        },
        {
          Header: 'Last Impression',
          accessor: 'lastImpression',
          className: 'last-impression',
          id: 'lastImpressionID',
          disableFilters: true,
          usesCachedData: true,
          sortType: (rowA, rowB) => {
            return dateSort(rowA, rowB, 'lastImpression');
          },
        },
        {
          Header: 'Last Submission',
          accessor: 'lastSubmission',
          className: 'last-submission',
          id: 'lastSubmissionID',
          disableFilters: true,
          usesCachedData: true,
          sortType: (rowA, rowB) => {
            return dateSort(rowA, rowB, 'lastSubmission');
          },
        },
        {
          Header: 'Last Change',
          accessor: 'lastChange',
          id: 'lastChangeID',
          className: 'last-change',
          disableFilters: false,
          filter: customDateFiltering,
          initialFilterValue: initialTextFilter('lastChangeID'),
          sortType: (rowA, rowB) => {
            return dateSort(rowA, rowB, 'lastChange');
          },
        },
        {
          Header: 'Edited By',
          accessor: 'editedBy',
          id: 'editedByID',
          disableFilters: false,
          filter: customORFiltering,
          options: props.surveyEditedByOptions.map((option) => {
            return ({
              ...option,
              initialCheckedState: initialCheckedState('editedByID', option.value),
            });
          }),
          sortType: (rowA, rowB) => {
            return caseInsensitiveSort(rowA, rowB, 'editedBy');
          },
        },
        {
          Header: 'Tags',
          accessor: 'tags',
          id: 'tagsID',
          disableFilters: false,
          filter: customORFiltering,
          options: props.surveyTagOptions.map((option) => {
            return ({...option,
              initialCheckedState: initialCheckedState('tagsID', option.value)
            });
          }),
          visible: false,
        },
        {
          Header: 'Created By',
          accessor: 'createdByName',
          id: 'createdByNameID',
          disableFilters: false,
          filter: customORFiltering,
          options: props.surveyCreatedByNameOptions.map((option) => {
            return ({
              ...option,
              initialCheckedState: initialCheckedState('createdByNameID', option.value)
            });
          }),
          visible: false,
        },
        {
          Header: 'Possible Answer IDs',
          accessor: 'possibleAnswerIds',
          id: 'possibleAnswerIdsID',
          disableFilters: false,
          filter: fuzzyTextFilter,
          visible: false,
        },
        {
          Header: 'Survey ID',
          accessor: 'surveyId',
          id: 'surveyID',
          disableFilters: false,
          filter: fuzzyTextFilter,
          visible: false,
        },
        {
          Header: 'Survey Locale Group ID',
          accessor: 'surveyLocaleGroupId',
          id: 'surveyLocaleGroupID',
          disableFilters: false,
          filter: fuzzyTextFilter,
          visible: false,
        },
        {
          Header: 'All Searchable Content',
          accessor: 'searchableContent',
          id: 'searchableContentID',
          disableFilters: false,
          filter: fuzzyTextFilter,
          visible: false,
        },
        {
          Header: 'Live On',
          accessor: 'liveAt',
          id: 'liveAtID',
          disableFilters: true,
          sortType: (rowA, rowB) => {
            return dateSort(rowA, rowB, 'liveAt');
          },
        },
      ],
      [],
  );

  const surveyRowDataProcessor = (survey, isSubrow=false) => {
    return {
      name: survey.name,
      status: survey.status,
      impressions: survey.impressions,
      submissions: survey.submissions,
      submissionRate: survey.submissionRate,
      goal: survey.goal,
      lastImpression: survey.lastImpression,
      lastSubmission: survey.lastSubmission,
      lastChange: survey.updatedAt,
      editedBy: survey.updatedByName,
      surveyId: survey.id,
      type: survey.type,
      rowLinks: survey.rowLinks,
      tags: survey.tags,
      createdByName: survey.createdByName,
      possibleAnswerIds: survey.possibleAnswerIds,
      searchableContent: survey.searchableContent,
      isSubrow: isSubrow,
      liveAt: survey.liveAt,
    };
  };

  const surveyLocaleGroupDataProcessor = (surveyLocaleGroup) => {
    return {
      name: surveyLocaleGroup.name,
      subRows: surveyLocaleGroup.subRows.map((survey) => {
        return subrowDataProcessor(survey);
      }),
      surveyLocaleGroupId: surveyLocaleGroup.id,
      type: surveyLocaleGroup.type,
      rowLinks: surveyLocaleGroup.rowLinks,
      impressions: surveyLocaleGroup.impressions,
      submissions: surveyLocaleGroup.submissions,
      submissionRate: surveyLocaleGroup.submissionRate,
      lastImpression: surveyLocaleGroup.lastImpression,
      lastSubmission: surveyLocaleGroup.lastSubmission,
      lastChange: surveyLocaleGroup.updatedAt,
      editedBy: surveyLocaleGroup.updatedByName,
    };
  };

  const subrowDataProcessor = (survey) => {
    return {
      ...surveyRowDataProcessor(survey),
      isSubrow: true,
    };
  };

  const [data, setData] = React.useState(
      () => props.surveys.map(
          (survey) => {
            switch (survey.type) {
              case 'survey':
                return (surveyRowDataProcessor(survey));
              case 'surveyLocaleGroup':
                return (surveyLocaleGroupDataProcessor(survey));
            }
          },
      ),
  );

  // Finds the survey matching the idea and performs an action on it.
  const updateSurveyRow = (surveyId, callback) => {
    setData((old) => {
      // It's important that we set the data to a new object.
      // React-Table does not like mutability.
      const newData = [...old];

      for (let rowIndex = 0; rowIndex < old.length; rowIndex++) {
        const row = newData[rowIndex];

        if (row.subRows) {
          const subrowIndex = row.subRows.findIndex((subRow) => {
            return subRow.surveyId === surveyId;
          });

          if (subrowIndex > -1) {
            callback(row.subRows, subrowIndex, true);
            break;
          }
        }

        if (row.surveyId === surveyId) {
          callback(newData, rowIndex, false);
          break;
        }
      }

      return newData;
    });
  };

  const addRow = (newSurvey, surveyId) => {
    updateSurveyRow(surveyId, (rows, index, isSubrow) =>
      rows.splice(index + 1, 0, surveyRowDataProcessor(newSurvey, isSubrow)),
    );
  };

  const removeRow = (surveyId) => {
    updateSurveyRow(surveyId, (rows, index, isSubrow) =>
      rows.splice(index, 1),
    );
  };

  // Updates the data structure defined above
  // Consider it a PUT update
  const updateReactTableDataRow = (surveyId, surveyLocaleGroupId, newRowValues) => {
    setData((old) =>
      old.map((row, index) => {
        let newSubRows = [];

        if (row.subRows) {
          newSubRows = row.subRows.map((subRow) => {
            if (surveyId && surveyId === subRow.surveyId) {
              return {
                ...subRow,
                ...newRowValues,
              };
            } else {
              return subRow;
            }
          });
        }

        if ((surveyId && surveyId === row.surveyId) ||
          (surveyLocaleGroupId && surveyLocaleGroupId === row.surveyLocaleGroupId)) {
          return {
            ...row,
            subRows: newSubRows,
            ...newRowValues,
          };
        }

        return {
          ...row,
          subRows: newSubRows,
        };
      }),
    );
  };

  // updates data on server
  // updates react-table model if successful
  const persistentUpdate = (dbColumnName, value, surveyId, surveyLocaleGroupId) => {
    let url = '';
    let payload = {};

    if (surveyId) {
      url = '/surveys/' + surveyId + '/inline_edit';
      payload = {survey: {}};
      payload.survey[dbColumnName] = value;
    } else if (surveyLocaleGroupId) {
      url = '/survey_locale_groups/' + surveyLocaleGroupId + '/inline_edit';
      payload = {survey_locale_group: {}};
      payload.survey_locale_group[dbColumnName] = value;
    } else {
      console.debug("error -- no record ID provided", jqXHR, textStatus, errorThrown);
      return;
    }

    $.ajax({
      url: url,
      method: 'POST',
      data: payload,
    }).done(function(_response) {
      updateReactTableDataRow(surveyId, surveyLocaleGroupId, {[dbColumnName]: value});
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('error updating record', jqXHR, textStatus, errorThrown);
    });
  };

  React.useEffect(() => {
    document.addEventListener('keydown', onKeyDown, false);
  }, []);

  const onKeyDown = (event) => {
    if (event.key === 'Escape') {
      setContextMenuHidden(true);
    }
  };

  const rightClickHandler = (e) => {
    // prevent browser's context menu from appearing
    e.preventDefault();

    // show context menu at new position
    setContextMenuHidden(false);
    setContextMenuPosition([e.pageX, e.pageY]);
  };

  const headerOutsideClickHandler = () => {
    setContextMenuHidden(true);
  };

  return <SurveyDashboardTable
    allowSurveyStatusChange={props.allowSurveyStatusChange}
    columns={columns}
    data={data}
    headerOutsideClickHandler={() => headerOutsideClickHandler()}
    headerRightClickHandler={(e) => rightClickHandler(e)}
    contextMenuPosition={contextMenuPosition}
    contextMenuHidden={contextMenuHidden}
    persistentUpdate={persistentUpdate}
    tagsLink={props.tagsLink}
    showChangeLogButton={props.showChangeLogButton}
    cacheDetails={props.cacheDetails}
    addRow={addRow}
    removeRow={removeRow}
    storedFilters={props.storedFilters}
  />;
}

export default SurveyDashboard;
