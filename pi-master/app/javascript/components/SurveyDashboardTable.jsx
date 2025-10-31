import React from 'react';
import PropTypes from 'prop-types';

import {
  useTable, useExpanded, useSortBy, useColumnOrder, useFilters,
} from 'react-table';
import {DragDropContext, Droppable, Draggable} from '@hello-pangea/dnd';

import FilterPanel from './FilterPanel';
import HeaderMenu from './survey_dashboard/HeaderMenu';
import HoverMenu from './survey_dashboard/HoverMenu';

import ArrowUp from '../images/survey_dashboard/arrow_up.svg';
import ArrowDown from '../images/survey_dashboard/arrow_down.svg';

import ResetIcon from '../images/survey_dashboard/reset.svg';

SurveyDashboardTable.propTypes = {
  allowSurveyStatusChange: PropTypes.bool.isRequired,
  columns: PropTypes.array.isRequired,
  data: PropTypes.array.isRequired,
  contextMenuHidden: PropTypes.bool.isRequired,
  contextMenuPosition: PropTypes.array.isRequired,
  headerOutsideClickHandler: PropTypes.func.isRequired,
  headerRightClickHandler: PropTypes.func.isRequired,
  persistentUpdate: PropTypes.func.isRequired,
  tagsLink: PropTypes.string.isRequired,
  showChangeLogButton: PropTypes.bool.isRequired,
  cacheDetails: PropTypes.object.isRequired,
  addRow: PropTypes.func.isRequired,
  removeRow: PropTypes.func.isRequired,
  storedFilters: PropTypes.array.isRequired,
};

/**
 * The survey dashboard's table
 * @return {JSX.Element} the table
 */
function SurveyDashboardTable(
    {
      allowSurveyStatusChange, columns, data, contextMenuHidden, contextMenuPosition,
      headerOutsideClickHandler, headerRightClickHandler, persistentUpdate,
      tagsLink, showChangeLogButton, cacheDetails, addRow,
      removeRow, storedFilters,
    },
) {
  const getItemStyle = ({isDragging, isDropAnimating}, draggableStyle) => ({
    ...draggableStyle,
    userSelect: 'none',

    ...(!isDragging && {transform: 'translate(0,0)'}),
    ...(isDropAnimating && {transitionDuration: '0.001s'}),
  });

  const columnOrderFromCookie = () => {
    const columnOrderCookie = document.cookie.split('; ').find((row) => {
      return row.startsWith('pi_survey_index_column_order');
    });

    if (columnOrderCookie === undefined) {
      return [];
    } else {
      return columnOrderCookie.split('=')[1].split(',');
    }
  };

  const defaultFilters = () => {
    return [
      {
        id: 'statusID', value: ['live', 'draft'],
      },
    ];
  };

  const initialFilters = () => {
    const filtersToApply = [...defaultFilters()];

    // add or overwrite the default
    storedFilters.forEach((storedFilter) => {
      let overwrite = false;
      for (let i = 0; i < filtersToApply.length; i++) {
        if (filtersToApply[i].id === storedFilter.id) {
          filtersToApply[i] = storedFilter;
          overwrite = true;
          break;
        }
      }

      if (!overwrite) {
        // We want to filter with Date objects, not date strings.
        if (storedFilter.id === 'lastChangeID') {
          storedFilter.value = storedFilter.value.map((filterValue) => {
            return new Date(filterValue);
          });
        }
        filtersToApply.push(storedFilter);
      }
    });

    return filtersToApply;
  };

  const tableInstance = useTable(
      {
        columns,
        data,
        initialState: {
          columnOrder: columnOrderFromCookie(),
          filters: initialFilters(),
          hiddenColumns: ['lastImpressionID'],
        },
        allowSurveyStatusChange: allowSurveyStatusChange,
        persistentUpdate,
        getSubRows: (row, relativeIndex) => {
          return row.subRows || [];
        },
        autoResetExpanded: false,
        autoResetFilters: false,
      },
      useFilters,
      useSortBy,
      useExpanded,
      useColumnOrder,
  );

  const {
    getTableProps,
    getTableBodyProps,
    headerGroups,
    rows,
    prepareRow,
    allColumns,
    setColumnOrder,
    setFilter,
    setAllFilters,
    flatRows,
    state,
  } = tableInstance;

  const currentColOrder = React.useRef();

  const CustomCell = ({cell}) => {
    const [hoverMenuVisible, setHoverMenuVisible] = React.useState(false);

    const hoverMenuId = (cell) => {
      return `hover_menu_${cell.row.type}_${cell.row.id}`;
    };

    const customGetCellProps = (cell) => {
      return {
        className: cell.column.className,
        onMouseEnter: (e) => {
          setHoverMenuVisible(true);
        },
        onMouseLeave: (e) => {
          setHoverMenuVisible(false);
        },
      };
    };

    const renderHoverMenu = (cell) => {
      if (cell.column.id === 'nameID') {
        const rowHoverMenuId = hoverMenuId(cell);

        // pass SLG, localized, unlocalized
        return <HoverMenu
          id={rowHoverMenuId}
          isVisible={hoverMenuVisible}
          rowLinks={cell.row.original.rowLinks}
          addRow={addRow}
          removeRow={removeRow}
          surveyId={cell.row.original.surveyId}
          surveyLocaleGroupId={cell.row.original.surveyLocaleGroupId}
        />;
      } else {
        return null;
      }
    };

    return (
      <td
        {...cell.getCellProps([customGetCellProps(cell)])}
      >
        <div>
          { cell.render('Cell') }
          { renderHoverMenu(cell) }
        </div>
      </td>
    );
  };

  const customGetRowProps = (row) => {
    let className = null;

    if (row.original.isSubrow) {
      className = 'subRow';
    } else if (row.original.surveyLocaleGroupId) {
      className = 'survey-locale-group-row';
    }

    return {
      'data-survey-id': row.original.surveyId,
      'className': className,
      'style': {
        borderTop: row.depth === 0 ? '2px solid #eaedf3' : '',
      },
    };
  };

  const customToggleSortProps = (column) => {
    const className = column.id == 'nameID' ? 'name-header-cell' : '';
    let title = '';

    if (column.usesCachedData && cacheDetails) {
      title = `Global caches last updated at: 
        ${cacheDetails.lastGlobalCacheAt}\n${cacheDetails.nextGlobalCache}`;
    } else {
      title = `Toggle sort: ${column.Header}`;
    }

    return {title: title, className: className};
  };

  const headerProps = (column) => {
    return column.getHeaderProps(
        column.getSortByToggleProps(customToggleSortProps(column)),
    );
  };

  React.useEffect(() => {
    allColumns.filter((column) => {
      return column.visible === false;
    }).forEach((column) => {
      column.toggleHidden();
    });
  }, []);

  const renderSummaryBanner = () => {
    const nameFilter = state.filters.find((filter) => filter.id === 'nameID');

    return (
      nameFilter ?
        <h4 className="summary-banner">
          {flatRows.length} {flatRows.length === 1 ? 'result' : 'results' } for &quot;{nameFilter.value}&quot;
        </h4> :
          null
    );
  };

  const hasResults = rows.length > 0;

  const sortingIcons = (column) => {
    if (column.isSorted) {
      return (
        <img
          className="sorting-icons"
          src={(column.isSortedDesc ? ArrowDown : ArrowUp)}
        >
        </img>
      );
    } else {
      return null;
    }
  };

  const renderTable = () => {
    return (
      <table {...getTableProps()} className='react-table'>
        <thead>
          {headerGroups.map((headerGroup, headerGroupIndex) => (
            <Droppable
              key={headerGroupIndex}
              droppableId="droppable"
              direction="horizontal"
            >
              {(droppableProvided, snapshot) => (
                <tr
                  {...headerGroup.getHeaderGroupProps()}
                  ref={droppableProvided.innerRef}
                  className="header-group"
                >
                  {headerGroup.headers.map((column, index) => (
                    <Draggable
                      key={column.id}
                      draggableId={column.id}
                      index={index}
                      isDragDisabled={!column.accessor}
                    >
                      {(provided, snapshot) => {
                        return (
                          <th
                            {...headerProps(column)}
                            onContextMenu={headerRightClickHandler}
                          >
                            <div
                              {...provided.draggableProps}
                              {...provided.dragHandleProps}
                              ref={provided.innerRef}
                              style={{
                                ...getItemStyle(
                                    snapshot,
                                    provided.draggableProps.style,
                                ),
                              }}
                              className='column-header-content-wrapper'
                            >
                              {column.render('Header')}
                              {sortingIcons(column)}
                            </div>
                          </th>
                        );
                      }}
                    </Draggable>
                  ))}
                </tr>
              )}
            </Droppable>
          ))}
        </thead>
        <tbody {...getTableBodyProps()}>
          {rows.map((row) => {
            prepareRow(row);
            return (
              <tr {...row.getRowProps(customGetRowProps(row))} >
                {row.cells.map((cell) => {
                  return (
                    <CustomCell
                      cell={cell}
                      key={`${row.id}-${cell.column.id}`}
                    />
                  );
                })}
              </tr>
            );
          })}
        </tbody>
      </table>
    );
  };

  const clearAllFilters = () => {
    // clear filters on the back end
    setAllFilters([]);

    // clear search params
    const url = new URL(window.location);
    const searchParams = new URLSearchParams(window.location.search);

    // if date range, which is not a front-end filter, was set
    // we'll need to reload the page.
    const reloadWhenDone = url.searchParams.get('from');

    searchParams.forEach((_value, key) => {
      url.searchParams.delete(key);
    });

    window.history.pushState({}, '', url);

    if (reloadWhenDone) {
      window.location.reload(true);
    }
  };

  const renderNoResults = () => {
    return (
      <div className="no-results-message">
        <p>
          There are no results for your search.
          <br />
          Please adjust your filters and search parameters.
        </p>
        <button
          className='clear-filters-button'
          onClick={clearAllFilters}
        >
          CLEAR ALL
        </button>
      </div>
    );
  };

  const clearFiltersButton = () => {
    return (
      <button
        className='clear-filters-button'
        onClick={clearAllFilters}
      >
        <img src={ResetIcon} />RESET FILTERS
      </button>
    );
  };

  return (
    <>
      <FilterPanel
        tableInstance={tableInstance}
        tagsLink={tagsLink}
        ClearFiltersButton={clearFiltersButton}
      />
      <DragDropContext
        // Handles drag and drop in table columns and header menu
        onDragStart={() => {
          currentColOrder.current = allColumns.map((column) => column.id);
        }}
        onDragUpdate={(dragUpdateObj) => {
        }}
        onDragEnd={(dragUpdateObj) => {
          if (dragUpdateObj.reason === 'DROP') {
            const colOrder = [...currentColOrder.current];
            const sIndex = dragUpdateObj.source.index;
            const dIndex = dragUpdateObj.destination &&
              dragUpdateObj.destination.index;

            if (typeof sIndex === 'number' && typeof dIndex === 'number') {
              let columnId = dragUpdateObj.draggableId;

              if (dragUpdateObj.source.droppableId === 'headerMenuDroppable') {
                // Draggable IDs in context menu and table headers must be
                // different, or dragging one will attempt to drag the other
                // simultaneously.
                //
                // This solution seems like a bit of a hack.
                columnId = columnId.replace(/_context_menu/g, '');
              }

              colOrder.splice(sIndex, 1);
              colOrder.splice(dIndex, 0, columnId);

              setColumnOrder(colOrder);
              document.cookie = `pi_survey_index_column_order=${colOrder.join(',')}; path=/`;
            }
          }
        }}
      >
        <HeaderMenu
          id='header_menu'
          allColumns={allColumns}
          isHidden={contextMenuHidden}
          position={contextMenuPosition}
          outsideClickHandler={headerOutsideClickHandler}
        />

        <div className="react-table-wrapper">
          { renderSummaryBanner() }

          { hasResults ? renderTable() : renderNoResults() }

          { showChangeLogButton ?
              <button
                className="audit-modal-trigger"
                onClick={() => $('#auditing_modal').modal()}
              >
                View Change Log
              </button> :
                null
          }
        </div>
      </DragDropContext>
    </>
  );
}

export default SurveyDashboardTable;
