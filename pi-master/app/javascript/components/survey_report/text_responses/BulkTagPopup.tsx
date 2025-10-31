import React from 'react';

import OutsideClickHandler from 'react-outside-click-handler';

import {matchSorter} from 'match-sorter';

import DebouncedInput from '../../DebouncedInput';
import IndeterminateCheckbox from './IndeterminateCheckbox';
import MagnifyingGlass from '../../../images/survey_dashboard/magnifying_glass.svg';
import {Tag, TagOption, UpdatedRowValue} from './Types';

interface BulkTagPopupProps {
  selectedRows: Array<Object>
  tagOptions: TagOption[]
  questionId: number
  updateTableBulk: (rows: Array<UpdatedRowValue>) => void
  closePopup: Function
  openTagManger: Function
};

/**
 * @param {BulkTagPopupProps} props
 * @return { JSX.Element }
 */
function BulkTagPopup(props: BulkTagPopupProps) {
  const [tagFilterValue, setTagFilterValue] = React.useState('');
  const [selectionState, setSelectionState] = React.useState(() => {
    return initialSelectionState();
  });

  const selectedAnswerIds = props.selectedRows.map((row) => {
    return row.getValue('answerId');
  });

  /**
   * The page polls for changes to tag options. When tag options change we must
   * keep our selection state in synch. New tag options need to be added and old
   * ones removed.
   */
  function synchronizeTagOptionsWithSelectionState() {
    const tagOptionIds = props.tagOptions.map((tagOption) => {
      return tagOption.id;
    });

    let newStates = undefined;
    tagOptionIds.forEach((tagOptionId) => {
      if (selectionState[tagOptionId] === undefined) {
        if (newStates === undefined) {
          newStates = {};
        }

        newStates[tagOptionId] = {
          some: false,
          all: false,
        };
      }
    });

    const statesToRemove = Object.keys(selectionState).filter((tagOptionId) => {
      return !tagOptionIds.includes(parseInt(tagOptionId));
    });

    if (statesToRemove.length != 0 || newStates !== undefined) {
      let updatedSelectionState = {...selectionState};

      statesToRemove.forEach((tagOptionId) => {
        delete updatedSelectionState[tagOptionId];
      });

      updatedSelectionState = {
        ...updatedSelectionState,
        ...newStates,
      };

      setSelectionState(updatedSelectionState);
    }
  }
  synchronizeTagOptionsWithSelectionState();

  /**
   * Returns filtered tag options
   *
   * @return { TagOption[] }
   **/
  function filteredTagOptions() {
    if (tagFilterValue.length > 0) {
      return matchSorter(props.tagOptions, tagFilterValue, {keys: ['text']});
    } else {
      return props.tagOptions;
    }
  }

  /**
   * Whether or not the filter value matches a tag exactly
   * @return { bool }
   **/
  function filterMatchesTagExactly() {
    return props.tagOptions.some((tagOption) => {
      return tagFilterValue === tagOption.text;
    });
  }

  /**
   * The initial tag selections for each selected row
   *
   * @return { Object }
   * id: { some:, all: }
   **/
  function initialSelectionState() {
    const result = {};

    const rowIncludesTagOption = (row, tagOption) => {
      return row.getValue('appliedTags').some((tag) => {
        return tag.tagId == tagOption.id;
      });
    };

    props.tagOptions.forEach((tagOption) => {
      result[tagOption.id] = {
        some: props.selectedRows.some((row) => {
          return rowIncludesTagOption(row, tagOption);
        }),
        all: props.selectedRows.every((row) => {
          return rowIncludesTagOption(row, tagOption);
        }),
      };
    });

    return result;
  };

  type Response = {
    answerId: number
    appliedTags: Tag[]
  }

  /**
   * Updates the selected rows of the table with new applied tags
   * @param { Response[] } answerData - the responses which have changed
   **/
  function updateTheTable(answerData: Response[]) {
    const updatedRows = props.selectedRows.map((row) => {
      const rowIndex = row.index;
      const columnId = 'appliedTags';

      const value = answerData.find((response) => {
        return response.answerId === row.getValue('answerId');
      }).appliedTags;

      return {
        rowIndex: rowIndex,
        columnId: columnId,
        value: value,
      };
    });

    props.updateTableBulk(updatedRows);
  }

  /**
   * Apply AppliedTag selection changes to the database
   **/
  function applyChanges() {
    const cachedInitialSelectionState = initialSelectionState();

    props.tagOptions.forEach((tagOption) => {
      const allBecameSelected = !cachedInitialSelectionState[tagOption.id].all &&
        selectionState[tagOption.id].all;

      if (allBecameSelected) {
        // Apply tags to all selected
        $.ajax({
          url: '/applied_tags/create_for_answers',
          method: 'POST',
          data: {
            tag_id: tagOption.id,
            answer_ids: selectedAnswerIds,
          },
        }).done(function(responseData) {
          console.debug('We did it!');
          updateTheTable(responseData.response);
        }).fail(function(jqXHR, textStatus, errorThrown) {
          console.debug('failed to update! D:', jqXHR, textStatus, errorThrown);
        });
      }

      const noneBecameSelected = cachedInitialSelectionState[tagOption.id].some &&
        !selectionState[tagOption.id].some;

      if (noneBecameSelected) {
        // Remove tags from all selected
        $.ajax({
          url: '/applied_tags/remove_from_answers',
          method: 'DELETE',
          data: {
            tag_id: tagOption.id,
            answer_ids: selectedAnswerIds,
          },
        }).done(function(responseData) {
          console.debug('We did it!');
          // update the table
          updateTheTable(responseData.response);
        }).fail(function(jqXHR, textStatus, errorThrown) {
          console.debug('failed to update! D:', jqXHR, textStatus, errorThrown);
        });
      }
    });
  }

  /**
   * Update internal selection  state
   *
   * @param {number} tagId - The tag ID that was selected/deselected
   * @param {boolean} checked - Whether the tag was selected or deselected
   **/
  function updateSelectionState(tagId: number, checked: boolean) {
    const newSelectionState = {...selectionState};

    if (newSelectionState[tagId] === undefined) {
      newSelectionState[tagId] = {some: true, all: true};
    } else {
      newSelectionState[tagId].all = checked;
      newSelectionState[tagId].some = checked;
    }

    setSelectionState(newSelectionState);
  }

  const tagChanges = () => {
    const changes = {
      numToApply: 0,
      numToRemove: 0,
    };

    const cachedInitialSelectionState = initialSelectionState();
    Object.keys(cachedInitialSelectionState).forEach((key) => {
      const initialValue = cachedInitialSelectionState[key];
      const currentValue = selectionState[key];

      if (currentValue === undefined) {
        console.debug("ERROR! could not find", key, "in", selectionState);
      } else {
        if (!initialValue.all && currentValue.all) {
          changes.numToApply++;
        } else if (initialValue.some && !currentValue.some) {
          changes.numToRemove++;
        }
      }
    });

    return changes;
  };

  const didTheyChangeACheckbox = () => {
    const cachedInitialSelectionState = initialSelectionState();

    return Object.keys(cachedInitialSelectionState).some((key) => {
      const initialValue = cachedInitialSelectionState[key];
      const currentValue = selectionState[key];

      return (initialValue.all !== currentValue.all ||
              initialValue.some !== currentValue.some);
    });
  };

  /**
   * Creates a new Tag as well as AppliedTag records for
   * each selected row.
   **/
  function createAndAddTagToRows() {
    $.ajax({
      url: '/tags/bulk_add',
      method: 'POST',
      data: {
        question_id: props.questionId,
        tag_name: tagFilterValue,
        answer_ids: selectedAnswerIds,
      },
    }).done(function(responseData) {
      updateTheTable(responseData.response);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed to create (or apply) Tag! D:', jqXHR, textStatus, errorThrown);
    });
  }

  return (
    <>
      <div className='tag-filter-wrapper'>
        <DebouncedInput
          type="text"
          value={(tagFilterValue ?? '') as string}
          onChange={(value) => setTagFilterValue(value.trim())}
          onKeyUp={(event) => {
            if (event.key == 'Enter' && !filterMatchesTagExactly()) {
              createAndAddTagToRows();
            }
          }}
        />
        <img className="magnifying-glass-icon" src={ MagnifyingGlass }></img>
      </div>
      {
        tagFilterValue && !filterMatchesTagExactly() ?
          <span>Tag not found. Press Enter to Add.</span> : null
      }
      <ul className='checkbox-list tag-options-list'>
        {
          filteredTagOptions().map((tag: TagOption) => {
            return (
              <li key={tag.id}>
                <label className={selectionState[tag.id]?.all ? 'checked' : ''}>
                  {
                    // selectionState might need a frame to update
                  }
                  <IndeterminateCheckbox
                    checked={selectionState[tag.id]?.all}
                    indeterminate={selectionState[tag.id]?.some}
                    onChange={(e) => {
                      updateSelectionState(tag.id, e.target.checked);
                    }}
                  />
                  { tag.text }
                </label>
              </li>
            );
          })
        }
      </ul>
      <hr />
      <Footer
        didTheyChangeACheckbox={didTheyChangeACheckbox}
        applyChanges={applyChanges}
        questionId={props.questionId}

        applyingTags={tagChanges().numToApply != 0}
        numTagsToApply={tagChanges().numToApply}
        removingTags={tagChanges().numToRemove != 0}
        numTagsToRemove={tagChanges().numToRemove}
        numSelected={props.selectedRows.length}

        openTagManager={props.openTagManager}
      />
    </>
  );
}

interface ChangeSummaryProps {
  applyingTags: boolean
  numTagsToApply: number
  removingTags: boolean
  numTagsToRemove: number
  numSelected: number
};

/**
 * A summary of the changes to be applied
 *
 * @param {ChangeSummaryProps} props
 * @return { JSX.Element }
 **/
function ChangeSummary(props: ChangeSummaryProps) {
  let responseString = '';

  if (props.applyingTags) {
    responseString += `Apply ${props.numTagsToApply} new tag(s) to`;

    if (props.removingTags) {
      responseString += 'and ';
    }
  }

  if (props.removingTags) {
    responseString += `Remove ${props.numTagsToRemove} tag(s) from `;
  }

  responseString += `${props.numSelected} selected responses.`;

  return <p className='change-summary'>{responseString}</p>;
}

interface FooterProps {
  didTheyChangeACheckbox: Function
  applyChanges: Function
  questionId: number

  applyingTags: boolean
  numTagsToApply: number
  removingTags: boolean
  numTagsToRemove: number
  numSelected: number

  openTagManager: Function
};

/**
 * @param {FooterProps} props
 * @return { JSX.Element }
 */
function Footer(props: FooterProps) {
  return (
    <ul className='actions-list'>
      {
        props.didTheyChangeACheckbox() ?
          <>
            <li>
              <ChangeSummary
                applyingTags={props.applyingTags}
                numTagsToApply={props.numTagsToApply}
                removingTags={props.removingTags}
                numTagsToRemove={props.numTagsToRemove}
                numSelected={props.numSelected}
              />
            </li>
            <li>
              <button onClick={props.applyChanges}>
                Apply Changes
              </button>
            </li>
          </> : null
      }

      <li>
        <button onClick={props.openTagManager} className='open-tag-manager'>
          Manage tags
        </button>
      </li>
    </ul>
  );
}

export default BulkTagPopup;
