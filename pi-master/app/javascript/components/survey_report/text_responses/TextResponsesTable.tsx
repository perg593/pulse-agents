import React from 'react';

import OutsideClickHandler from 'react-outside-click-handler';

import {useVirtualizer} from '@tanstack/react-virtual';

import {
  createColumnHelper,
  getCoreRowModel,
  useReactTable,
  VisibilityState,
  ColumnFiltersState,
  ColumnOrderState,
  FilterFn,
  getFilteredRowModel,
  getFacetedRowModel,
  getFacetedUniqueValues,
  getFacetedMinMaxValues,
  GroupingState,
  getGroupedRowModel,
  getExpandedRowModel,
  getSortedRowModel,
  SortingState,
} from '@tanstack/react-table';

import {
  rankItem,
} from '@tanstack/match-sorter-utils';

import AutotagMenu from './AutotagMenu';
import AutotagSlider from './AutotagSlider';
import BulkTagMenu from './BulkTagMenu';
import Cell from './Cell';
import CSVDownloadLink from './CSVDownloadLink';
import ColumnVisibilityDropdown from './ColumnVisibilityDropdown';
import ColumnGroupingMenu from './ColumnGroupingMenu';
import IndeterminateCheckbox from './IndeterminateCheckbox';
import Spinner from '../../Spinner';
import TableHeader from './TableHeader';
import TagCell from './TagCell';
import TagManager from "./TagManager";

import {
  Answer, AutoTagAnswersResponseTags, Question, TagOption, UpdatedRowValue,
} from './Types';
import RowSelectionDropdown from './RowSelectionDropdown';

declare module '@tanstack/table-core' {
  interface ColumnMeta<TData extends RowData, TValue> {
    formatForCsv?: (value: any) => any
    dragDisabled?: boolean
    resizeDisabled?: boolean
    groupingDisabled?: boolean
    titleized?: string
    includeSearchSuggestions?: boolean
    includeInCSV: boolean
    sortingDisabled?: boolean
    filterOptions?: Array<Object>
  }
}

const fuzzyFilter: FilterFn<any> = (row, columnId, value, addMeta) => {
  // Rank the item
  const itemRank = rankItem(row.getValue(columnId), value);

  // Store the itemRank info
  addMeta({
    itemRank,
  });

  // Return if the item should be filtered in/out
  return itemRank.passed;
};

const multipleSelectionFilter: FilterFn<any> = (row, columnId, columnSelectionStatuses, addMeta) => {
  if (Object.values(columnSelectionStatuses).every((checked) => !checked)) {
    return true;
  }

  return Object.keys(columnSelectionStatuses).some((key) => {
    return columnSelectionStatuses[key] === true && key === row.getValue(columnId);
  });
};

const tagFilter: FilterFn<any> = (row, columnId, tagSelectionValues, addMeta) => {
  if (Object.values(tagSelectionValues).every((checked) => !checked)) {
    return true;
  }

  return row.getValue(columnId).some((tag) => tagSelectionValues[tag.tagId]) ||
    (tagSelectionValues['Pending Approval'] && row.getValue('containsTagPendingApproval')) ||
    (tagSelectionValues['Untagged'] && row.getValue(columnId).length == 0);
};

const columnHelper = createColumnHelper<Answer>();

interface TextResponsesTableProps {
  autotagEnabled: boolean
  question: Question
  tableData: Answer[]
  tagOptions: TagOption[]
  surveyId: number
};

/**
 * @param {TextResponsesTableProps} props
 * @return { JSX.Element }
 */
function TextResponsesTable(props: TextResponsesTableProps) {
  const [data, setData] = React.useState(() => [...props.tableData]);
  const [grouping, setGrouping] = React.useState<GroupingState>([]);
  const [working, setWorking] = React.useState(false);
  const [tagOptions, setTagOptions] = React.useState(props.tagOptions);
  const [sorting, setSorting] = React.useState<SortingState>([]);
  const [multiselectRoot, setMultiselectRoot] = React.useState(null);
  const [showTagManager, setShowTagManager] = React.useState(false);

  const dateSort: SortingFn<TData> = (rowA: Row<TData>, rowB: Row<TData>, columnId: string) => {
    const dateA = new Date(rowA.original[columnId]);
    const dateB = new Date(rowB.original[columnId]);

    return Math.sign(dateA - dateB);
  };

  const columns = [
    columnHelper.display({
      id: 'select',
      header: function HeaderContainer({table}) {
        return (
          <div className='row-selection-wrapper'>
            <IndeterminateCheckbox
              checked={table.getIsAllRowsSelected()}
              indeterminate={table.getIsSomeRowsSelected()}
              onChange={table.getToggleAllRowsSelectedHandler()}
            />
            <RowSelectionDropdown
              table={table}
              autotagEnabled={props.autotagEnabled}
            />
          </div>
        );
      },
      cell: function CellContainer({row}) {
        return (
          <input
            type='checkbox'
            checked={row.getIsSelected()}
            onChange={() => rowClickHandling(row)}
          />
        );
      },
      meta: {
        dragDisabled: true,
        resizeDisabled: true,
        groupingDisabled: true,
        includeInCSV: false,
        sortingDisabled: true,
      },
    }),
    columnHelper.accessor('textResponse', {
      id: 'response',
      minSize: 290,
      header: () => <span>Response</span>,
      meta: {
        groupingDisabled: true,
        titleized: 'Response',
        includeSearchSuggestions: false,
        includeInCSV: true,
      },
    }),
    columnHelper.accessor('appliedTags', {
      id: 'appliedTags',
      minSize: 200,
      header: () => <span>Tags</span>,
      cell: function CellContainer({getValue, row}) {
        return (
          <TagCell
            tagOptions={tagOptions}
            questionId={props.question.id}
            updateTable={updateData}
            updateTableBulk={updateDataBulk}
            getAppliedTags={getValue}
            row={row}
            openTagManager={() => setShowTagManager(true)}
          />
        );
      },
      filterFn: 'tagFilter',
      meta: {
        formatForCsv: (value) => value.map((val) => val.text),
        groupingDisabled: true,
        titleized: 'Applied Tags',
        includeInCSV: true,
      },
    }),
    columnHelper.accessor('completionUrl', {
      id: 'completionUrl',
      minSize: 290,
      header: () => <span>Completion URL</span>,
      meta: {
        titleized: 'Completion URL',
        includeInCSV: true,
      },
    }),
    columnHelper.accessor('createdAt', {
      id: 'createdAt',
      minSize: 250,
      header: () => <span>Time</span>,
      sortingFn: dateSort,
      meta: {
        groupingDisabled: true,
        titleized: 'Created At',
        includeSearchSuggestions: false,
        includeInCSV: true,
      },
    }),
    columnHelper.accessor('sentiment', {
      id: 'sentiment',
      minSize: 250,
      header: () => <span>Sentiment</span>,
      filterFn: 'multipleSelectionFilter',
      meta: {
        titleized: 'Sentiment',
        includeInCSV: true,
        filterOptions: [
          {key: 'Very Negative', label: 'Very Negative'},
          {key: 'Negative', label: 'Negative'},
          {key: 'Neutral', label: 'Neutral'},
          {key: 'Positive', label: 'Positive'},
          {key: 'Very Positive', label: 'Very Positive'},
        ],
      },
    }),
    columnHelper.accessor('deviceType', {
      id: 'deviceType',
      minSize: 250,
      header: () => <span>Device Type</span>,
      filterFn: 'multipleSelectionFilter',
      meta: {
        titleized: 'Device Type',
        includeInCSV: true,
        filterOptions: [
          {key: 'email', label: 'email'},
          {key: 'mobile', label: 'mobile'},
          {key: 'tablet', label: 'tablet'},
          {key: 'native_mobile', label: 'native mobile'},
          {key: 'desktop', label: 'desktop'},
        ],
      },
    }),
    columnHelper.accessor('customData', {
      id: 'customData',
      minSize: 270,
      header: () => <span>Context Data</span>,
      meta: {
        formatForCsv: (value) => {
          return value === null ? '' : `${value}`.replace(/"/g, '""');
        },
        titleized: 'Context Data',
        includeInCSV: true,
      },
    }),
    columnHelper.accessor('deviceData', {
      id: 'deviceData',
      minSize: 270,
      header: () => <span>Device Data</span>,
      meta: {
        formatForCsv: (value) => {
          return value === null ? '' : `${value}`.replace(/"/g, '""');
        },
        titleized: 'Device Data',
        includeInCSV: true,
      },
    }),
    columnHelper.accessor('translation', {
      id: 'translation',
      minSize: 310,
      header: () => <span>Translation</span>,
      meta: {
        groupingDisabled: true,
        titleized: 'Translation',
        includeSearchSuggestions: false,
        includeInCSV: true,
      },
    }),
    columnHelper.accessor('id', {
      id: 'answerId',
      meta: {
        includeInCSV: false,
        groupingDisabled: true,
      },
    }),
    columnHelper.accessor(
        (row) => row.appliedTags.some((tag) => !tag.tagApproved),
        {
          id: 'containsTagPendingApproval',
          meta: {
            includeInCSV: false,
            groupingDisabled: true,
          },
        },
    ),
  ];

  const getStoredColumnOrder = () => {
    const item = window.localStorage.getItem('pi_text_responses_column_order');

    return item?.split(',');
  };

  const getStoredColumnVisibility = () => {
    const item = window.localStorage.getItem('pi_text_responses_column_visibility');

    const result = {};

    // "col_1:t,col_2:f"
    item?.split(',').forEach((columnSetting) => {
      const columnName = columnSetting.split(':')[0];
      const visibility = columnSetting.split(':')[1];

      result[columnName] = visibility === 't';
    });

    return result;
  };

  const [
    columnVisibility,
    setColumnVisibility,
  ] = React.useState<VisibilityState>(() => {
    const storedColumnVisibility = getStoredColumnVisibility();

    return {
      'select': storedColumnVisibility['select'] ?? true,
      'response': storedColumnVisibility['response'] ?? true,
      'appliedTags': storedColumnVisibility['appliedTags'] ?? true,
      'completionUrl': storedColumnVisibility['completionUrl'] ?? true,
      'createdAt': storedColumnVisibility['createdAt'] ?? true,
      'sentiment': storedColumnVisibility['sentiment'] ?? true,
      'customData': storedColumnVisibility['customData'] ?? false,
      'deviceType': storedColumnVisibility['deviceType'] ?? false,
      'deviceData': storedColumnVisibility['deviceData'] ?? false,
      'translation': storedColumnVisibility['translation'] ?? false,
      'containsTagPendingApproval': storedColumnVisibility['containsTagPendingApproval'] ?? false,
      'answerId': storedColumnVisibility['answerId'] ?? false,
    };
  });

  const [rowSelection, setRowSelection] = React.useState({});

  const [
    columnFilters,
    setColumnFilters,
  ] = React.useState<ColumnFiltersState>([]);

  const [
    columnOrder,
    setColumnOrder,
  ] = React.useState<ColumnOrderState>(() => {
    return getStoredColumnOrder() ?? [
      'select',
      'response',
      'appliedTags',
      'completionUrl',
      'createdAt',
      'sentiment',
      'deviceType',
      'customData',
      'deviceData',
      'translation',
      'answerId',
      'containsTagPendingApproval',
    ];
  });

  React.useEffect(() => {
    storeColumnOrder();
  }, [columnOrder]);

  const storeColumnOrder = () => {
    window.localStorage.setItem('pi_text_responses_column_order', columnOrder.join(','));
  };

  React.useEffect(() => {
    storeColumnVisibility();
  }, [columnVisibility]);

  const storeColumnVisibility = () => {
    const visibility = Object.keys(columnVisibility).filter((key) => {
      return columnVisibility[key] !== undefined;
    }).map((key) => {
      const val = columnVisibility[key] ? 't' : 'f';

      return `${key}:${val}`;
    });

    window.localStorage.setItem('pi_text_responses_column_visibility', visibility.join(','));
  };

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    state: {
      columnVisibility,
      rowSelection,
      columnFilters,
      grouping,
      sorting,
      columnOrder,
    },
    onSortingChange: setSorting,
    getSortedRowModel: getSortedRowModel(),
    onColumnFiltersChange: setColumnFilters,
    onColumnVisibilityChange: setColumnVisibility,
    onGroupingChange: setGrouping,
    getGroupedRowModel: getGroupedRowModel(),
    getExpandedRowModel: getExpandedRowModel(),
    columnResizeMode: 'onChange',
    enableRowSelection: true,
    onRowSelectionChange: setRowSelection,
    filterFns: {
      fuzzy: fuzzyFilter,
      tagFilter: tagFilter,
      multipleSelectionFilter: multipleSelectionFilter,
    },
    getFilteredRowModel: getFilteredRowModel(),
    getFacetedRowModel: getFacetedRowModel(),
    getFacetedUniqueValues: getFacetedUniqueValues(),
    getFacetedMinMaxValues: getFacetedMinMaxValues(),
  });

  /**
   * Updates multiple table rows
   *
   * @param { Array<UpdatedRowValue> } rowsToUpdate
   **/
  function updateDataBulk(rowsToUpdate :Array<UpdatedRowValue>) {
    const validColumnIds = columns.map((column) => column.id);

    setData((oldRows) => {
      return oldRows.map((row, index) => {
        const rowToUpdate= rowsToUpdate.find((rowToChange) => {
          return index === rowToChange.rowIndex;
        });

        if (rowToUpdate !== undefined) {
          if (!validColumnIds.includes(rowToUpdate.columnId)) {
            throw new Error(`invalid columnId ${rowToUpdate.columnId}`);
          }

          return {
            ...row,
            [rowToUpdate.columnId]: rowToUpdate.value,
          };
        } else {
          return row;
        }
      });
    });
  }

  /**
   * Updates the table's data for a particular cell
   *
   * @param { UpdatedRowValue } updatedRowValue
   **/
  function updateData(updatedRowValue: UpdatedRowValue) {
    updateDataBulk([updatedRowValue]);
  };

  /**
   * Add a collection of new AppliedTags to specified answers
   *
   * @param { Array<AutoTagAnswersResponseTags> } appliedTags - Array of
   *   new appliedTags
   **/
  function addNewAppliedTags(appliedTags: Array<AutoTagAnswersResponseTags>) {
    setData((oldRows) => {
      return oldRows.map((row, index) => {
        const appliedTagsForAnswer = appliedTags.filter((appliedTag) => {
          return appliedTag.answerId === row.id;
        });

        if (appliedTagsForAnswer.length == 0) {
          return row;
        } else {
          const updatedAppliedTags = [...row.appliedTags];

          appliedTagsForAnswer.forEach((appliedTag) => {
            const newAppliedTag = {
              appliedTagId: appliedTag.appliedTagId,
              id: appliedTag.id,
              text: appliedTag.name,
              tagApproved: false,
              tagColor: appliedTag.color,
            };

            updatedAppliedTags.push(newAppliedTag);
          });
          return {
            ...row,
            appliedTags: updatedAppliedTags,
          };
        }
      });
    });
  }

  /**
   * Mark all applied tags as approved for the answers with the provided IDs.
   *
   * @param { Array<number> } answerIds - Array of answerIds
   **/
  function markAppliedTagsAsApprovedForAnswers(answerIds: Array<number>) {
    setData((oldRows) => {
      return oldRows.map((row, index) => {
        if (answerIds.includes(row.id)) {
          const updatedAppliedTags = row.appliedTags.map((appliedTag) => {
            return {
              ...appliedTag,
              tagApproved: true,
            };
          });

          return {
            ...row,
            appliedTags: updatedAppliedTags,
          };
        } else {
          return row;
        }
      });
    });
  }

  /**
   * Remove all applied tags from the answers with the provided IDs.
   *
   * @param { Array<number> } answerIds - Array of answerIds
   **/
  function removeAppliedTagsFromAnswers(answerIds: Array<number>) {
    setData((oldRows) => {
      return oldRows.map((row, index) => {
        if (answerIds.includes(row.id)) {
          const updatedRow = {
            ...row,
            appliedTags: [],
          };

          return updatedRow;
        } else {
          return row;
        }
      });
    });
  }

  /**
   * Update a tag and applied tags associated with the provided tag id.
   *
   * @param { number } tagOptionId - The id of a tag
   * @param { text } updatedName - The name to update to
   * @param { text } updatedColor - The color to update to
   *
   **/
  function updateTagOptionAndAppliedTags(tagOptionId, updatedName = null, updatedColor = null) {
    const parameters = {
      tag_id: tagOptionId,
      tag: {
        ...(updatedName && {name: updatedName}),
        ...(updatedColor && {color: updatedColor}),
      },
    };
    $.ajax({
      url: `/questions/${props.question.id}/update_tag`,
      method: 'PATCH',
      data: parameters,
    }).done(function(response) {
      setTagOptions((previousTagOptions) => {
        const updatedTagOptions = previousTagOptions.map((tagOption) => {
          if (tagOption.id === response.id) {
            return {...tagOption, text: response.text, color: response.color};
          }
          return tagOption;
        });
        return updatedTagOptions.sort((tagOption, tagOption2) => {
          return tagOption.text.localeCompare(tagOption2.text);
        });
      });
      setData((oldRows) => {
        return oldRows.map((oldRow) => {
          const updatedAppliedTags = oldRow.appliedTags.map((appliedTag) => {
            if (appliedTag.tagId === response.id) {
              return {...appliedTag, text: response.text, tagColor: response.color};
            } else {
              return appliedTag;
            }
          });
          return {...oldRow, appliedTags: updatedAppliedTags};
        });
      });
    }).fail(function(_response) {
      console.log('Failed to Update Tag');
    });
  }

  /**
   * Remove all applied tags associated with the provided tag id.
   *
   * @param { number } tagOptionId - The id of a tag
   **/
  function deleteTagOptionAndAppliedTags(tagOptionId) {
    $.ajax({
      url: `/questions/${props.question.id}/delete_tag`,
      method: 'DELETE',
      data: {tag_id: tagOptionId},
    }).done(function(response) {
      setTagOptions((previousTagOptions) => {
        return previousTagOptions.filter((tagOption) => {
          return tagOption.id != response.tagId;
        });
      });
      setData((oldRows) => {
        return oldRows.map((oldRow) => {
          const updatedAppliedTags = oldRow.appliedTags.filter((appliedTag) => {
            return appliedTag.tagId != tagOptionId;
          });
          return {...oldRow, appliedTags: updatedAppliedTags};
        });
      });
    }).fail(function(_response) {
      console.log('Failed to Delete Tag');
    });
  }

  const tableContainerRef = React.useRef<HTMLDivElement>(null);

  const { rows } = table.getRowModel()
  const rowVirtualizer = useVirtualizer({
    getScrollElement: () => tableContainerRef.current,
    count: rows.length,
    overscan: 100,
    estimateSize: () => 50,
  });
  const formattedNumRows = new Intl.NumberFormat().format(rows.length);

  const virtualRows = rowVirtualizer.getVirtualItems();
  const totalSize = rowVirtualizer.getTotalSize();

  const paddingTop = virtualRows[0]?.start || 0;
  const paddingBottom = virtualRows.length > 0 ? totalSize - (virtualRows[virtualRows.length - 1]?.end || 0) : 0;

  /**
   * @param {Row} row - The row that was clicked
   *   toggled directly
   **/
  function rowClickHandling(row :Row) {
    if (window.event.shiftKey && multiselectRoot) {
      const minIndex = Math.min(multiselectRoot.index, row.index);
      const maxIndex = Math.max(multiselectRoot.index, row.index);
      const rowsToSelect = {};

      for (let i = minIndex; i <= maxIndex; i++) {
        rowsToSelect[i] = true;
      }

      table.setRowSelection(rowsToSelect);
    } else {
      row.toggleSelected();
      setMultiselectRoot(row);
    }
  }

  return (
    <div className='table-wrapper'>
      {
        showTagManager ?
          <>
            <div className='tag-manager-overlay'></div>
            <OutsideClickHandler onOutsideClick={() => setShowTagManager(false)}>
              <TagManager
                questionId={props.question.id}
                tags={tagOptions}
                setTags={setTagOptions}
                updateTagAndAppliedTags={updateTagOptionAndAppliedTags}
                deleteTagAndAppliedTags={deleteTagOptionAndAppliedTags}
                closeTagManager={() => setShowTagManager(false)}
                aiTagRecommendationEnabled={props.autotagEnabled}/>
            </OutsideClickHandler>
          </> : null
      }
      <div className='question-header-container'>
        <h1 className='question-header'>{ props.question.content }</h1>

        {
          props.autotagEnabled ?
            <AutotagSlider
              autotagEnabled={props.question.autotagEnabled}
              questionId={props.question.id}
            /> : null
        }

        <a
          href={`/surveys/${props.surveyId}/report${location.search}`}
          className='close-button'
        >
          ×
        </a>
      </div>
      <div className='table-actions-container'>
        <BulkTagMenu
          tagOptions={tagOptions}
          selectedRows={table.getSelectedRowModel().rows}
          questionId={props.question.id}
          updateTableBulk={updateDataBulk}
          disabled={
            !table.getIsAllRowsSelected() &&
            !table.getIsSomeRowsSelected()
          }
          openTagManager={() => setShowTagManager(true)}
        />

        {
          props.autotagEnabled ?
              <AutotagMenu
                selectedRows={table.getSelectedRowModel().rows}
                questionId={props.question.id}
                setWorking={setWorking}
                removeAppliedTagsFromAnswers={removeAppliedTagsFromAnswers}
                markAppliedTagsAsApprovedForAnswers={markAppliedTagsAsApprovedForAnswers}
                addNewAppliedTags={addNewAppliedTags}
                disabled={
                  !table.getIsAllRowsSelected() &&
                  !table.getIsSomeRowsSelected()
                }
              /> : null
        }

        <ColumnGroupingMenu
          columns={() => {
            return table.getAllColumns().filter((column) => {
              return column.getIsVisible();
            });
          }}
        />

        <ColumnVisibilityDropdown
          columnOptions={() => {
            // TODO: Define this some other way
            const blacklist = ['answerId', 'containsTagPendingApproval', 'select'];

            return table.getAllLeafColumns().filter((column) => {
              return !blacklist.includes(column.id);
            });
          }}
          columnOrder={columnOrder}
          setColumnOrder={setColumnOrder}
        />

        {
          grouping.length === 0 ?
            <CSVDownloadLink
              columns={columns}
              table={table}
            /> : null
        }
      </div>
      <div ref={tableContainerRef} className='table-container'>
        <div className={`working-overlay ${working ? '' : 'hidden'}`}>
          <Spinner className='working-overlay-spinner' />
        </div>
        <table className='text-response-table'>
          <TableHeader
            headerGroups={table.getHeaderGroups()}
            tagOptions={tagOptions}
            autotagEnabled={props.autotagEnabled}
            columnOrder={columnOrder}
            setColumnOrder={setColumnOrder}
            visibleColumns={table.getVisibleLeafColumns()}
          />
          <tbody>
            {
              paddingTop > 0 ? (
                <tr>
                  <td style={{height: `${paddingTop}px`}} />
                </tr>
              ) : null
            }
            {
              virtualRows.map((virtualRow, index) => {
                const row = rows[virtualRow.index];

                const rowClass = () => {
                  let className = index % 2 == 0 ? 'even' : 'odd';

                  if (row.getIsSelected()) {
                    className += ' selected';
                  }

                  return className;
                };

                return (
                  <tr
                    key={row.id}
                    className={rowClass()}
                    onClick={() => {
                      if (window.event.shiftKey || window.event.metaKey) {
                        rowClickHandling(row);
                      }
                    }}
                  >
                    {
                      row.getVisibleCells().map((cell) => {
                        const metaData = cell.column.columnDef.meta;

                        return (
                          <td
                            key={cell.id}
                            className={`${cell.column.id}-column`}
                            style={
                              metaData.resizeDisabled ? null :
                                {width: cell.column.getSize()}
                            }
                          >
                            <Cell cell={cell} row={row} />
                          </td>
                        );
                      })
                    }
                  </tr>
                );
              })
            }
            {
              paddingBottom > 0 ? (
                <tr>
                  <td style={{height: `${paddingBottom}px`}} />
                </tr>
              ) : null
            }
          </tbody>
        </table>
      </div>

      {
        table.getSelectedRowModel().rows.length > 0 ?
          `${table.getSelectedRowModel().rows.length} Selected of ${formattedNumRows}` : null
      }

      {
        virtualRows.length === 0 ?
          <div className='no-data-container'>
            <h1>No data</h1>
            <span>Try</span> <a
              href='#'
              onClick={() => table.resetColumnFilters()}
            >
              resetting your filters
            </a>
          </div>: null
      }
    </div>
  );
}

export default TextResponsesTable;
