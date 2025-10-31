import React from 'react';

import {matchSorter} from 'match-sorter';
import OutsideClickHandler from 'react-outside-click-handler';

import DebouncedInput from '../../DebouncedInput';
import FilterIcon from '../../../images/filter_list_black_24dp.svg';

interface FilterProps {
  column: Column<any, unknown>[]
  checklistOptions: Array// TODO: be more specific
};

/**
 * A container for selecting multiple filtering options
 * The options themselves can also be filtered
 *
 * @param {FilterProps} props -- see interface above
 * @return {JSX.Element}
 **/
function MultipleSelectionFilter(props: FilterProps) {
  const [showPanel, setShowPanel] = React.useState(false);
  const [panelPosition, setPanelPosition] = React.useState([0, 0]);

  const [optionFilterValue, setOptionFilterValue] = React.useState('');

  const defaultFilters = () => {
    const filters = {};

    props.checklistOptions.forEach((option) => {
      filters[option.key] = false;
    });

    return filters;
  };

  const [filterState, setFilterState] = React.useState(defaultFilters);

  // Our filter may have been cleared outside via a reset button
  if (props.column.getFilterValue() === undefined &&
    JSON.stringify(filterState) !== JSON.stringify(defaultFilters())) {

    setFilterState(defaultFilters());
  }

  const numSelected = Object.values(filterState).filter((checked) => checked).length;

  const activatePanel = (e) => {
    setShowPanel(true);

    const pageWidth = document.body.offsetWidth;
    let panelX = e.clientX;

    // It's not rendered yet, so this is just a rough approximation
    const approximatePanelWidth = 230;
    if (pageWidth - panelX < approximatePanelWidth) {
      panelX -= approximatePanelWidth;
    }

    setPanelPosition([panelX, e.clientY]);
  };

  /**
   * Returns filtered options
   *
   * @return { MultipleSelectionFilterOption[] }
   **/
  function filteredOptions() {
    if (optionFilterValue.length > 0) {
      return matchSorter(props.checklistOptions, optionFilterValue, {keys: ['label']});
    } else {
      return props.checklistOptions;
    }
  }

  /**
   * Restore default filters
   **/
  function clearFilter() {
    setFilterState(defaultFilters);
    props.column.setFilterValue(defaultFilters);
  }

  return (
    <>
      <div
        className={`filter-button-container ${numSelected > 0 ? 'filters-active' : ''}`}
        onClick={(e) => activatePanel(e)}
      >
        <div
          className='filter-icon'
          style={{
            maskImage: `url(${FilterIcon})`,
            WebkitMaskImage: `url(${FilterIcon})`,
          }}
        >
        </div>
        <span>Filter</span>
        {
          numSelected > 0 ?
            <>
              <span className='filter-count-indicator'>
                {numSelected}
              </span>
              <span
                onClick={(e) => {
                  e.stopPropagation();
                  clearFilter();
                }}
              >
                ×
              </span>
            </>: null
        }
      </div>

      {
        showPanel ?
          <div className='outside-click-handler-wrapper'>
            <OutsideClickHandler onOutsideClick={() => setShowPanel(false)} >
              <div
                className='popup-menu filter-popup'
                style={{
                  left: `${panelPosition[0]}px`,
                  top: `${panelPosition[1]}px`,
                }}
              >
                <DebouncedInput
                  type="text"
                  value={(optionFilterValue ?? '') as string}
                  onChange={(value) => setOptionFilterValue(value.trim())}
                  placeholder='Search Options'
                  list={props.column.id + 'list'}
                />
                <ul className='checkbox-list'>
                  {
                    filteredOptions().map((option) => {
                      return (
                        <li key={option.key}>
                          <label>
                            <input
                              type='checkbox'
                              checked={filterState[option.key]}
                              onChange={(e) => {
                                const newFilterState = {
                                  ...filterState,
                                };

                                newFilterState[option.key] = e.target.checked;

                                setFilterState(newFilterState);

                                props.column.setFilterValue(newFilterState);
                              }}
                            />
                            {option.label}
                          </label>
                        </li>
                      );
                    })
                  }
                </ul>
              </div>
            </OutsideClickHandler>
          </div> : null
      }
    </>
  );
}

export default MultipleSelectionFilter;
