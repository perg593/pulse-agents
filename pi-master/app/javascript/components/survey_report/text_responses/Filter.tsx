import React from 'react';

import DebouncedInput from '../../DebouncedInput';
import MultipleSelectionFilter from './MultipleSelectionFilter';
import CloseMark from '../../../images/close_black_24dp.svg';

interface FilterProps {
  column: Column<any, unknown>[]
  tagOptions: TagOption[]
  autotagEnabled: boolean
};

/**
 * A filter input for a react-table
 *
 * @param {FilterProps} props
 * @return {HTMLInputElement}
 **/
function Filter(props: FilterProps) {
  const columnFilterValue = props.column.getFilterValue();

  const sortedUniqueValues = React.useMemo(
      () =>
        Array.from(props.column.getFacetedUniqueValues().keys()).sort(),
      [props.column.getFacetedUniqueValues()],
  );

  /**
   * Render a list of filtered elements. Used to provide options for dropdown.
   *
   * @return {JSX.Element} - A datalist of all matching options
   **/
  function SuggestionList() {
    if (props.column.columnDef.meta.includeSearchSuggestions === false) {
      return null;
    }

    return (
      <datalist id={props.column.id + 'list'}>
        {
          // 5K seems like a good threshold. Lower it if performance suffers.
          sortedUniqueValues.slice(0, 5000).map((value: any) => {
            return (
              <option value={value} key={value} />
            );
          })
        }
      </datalist>
    );
  };

  if (props.column.id === 'appliedTags') {
    // key-label pairs for each tag filter option
    const checklistOptions = () => {
      const options = [{key: 'Untagged', label: 'Untagged'}];

      if (props.autotagEnabled) {
        options.push({key: 'Pending Approval', label: 'Pending Approval'});
      }

      props.tagOptions.forEach((tagOption: TagOption) => {
        options.push({key: tagOption.id, label: tagOption.text});
      });

      return options;
    };

    return (
      <MultipleSelectionFilter
        column={props.column}
        checklistOptions={checklistOptions()}
      />
    );
  } else if (['deviceType', 'sentiment'].includes(props.column.id)) {
    return (
      <MultipleSelectionFilter
        column={props.column}
        checklistOptions={props.column.columnDef.meta.filterOptions}
      />
    );
  } else {
    return (
      <>
        <SuggestionList />
        <DebouncedInput
          type="text"
          value={(columnFilterValue ?? '') as string}
          onChange={(value) => {
            props.column.setFilterValue(value);
          }}
          placeholder='Search' // TODO: Add 'x' to clear
          className={`${props.column.id}-filter-input`}
          list={props.column.id + 'list'}
        />
        <span
          className='clear-filter'
          style={{
            maskImage: `url(${CloseMark})`,
            WebkitMaskImage: `url(${CloseMark})`,
          }}
          onClick={() => {
            props.column.setFilterValue('');
          }}>
        </span>
      </>
    );
  }
}

export default Filter;
