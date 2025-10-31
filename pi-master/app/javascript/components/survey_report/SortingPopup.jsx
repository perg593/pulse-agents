import React from 'react';
import PropTypes from 'prop-types';

import OutsideClickHandler from 'react-outside-click-handler';

import RadioControl from './RadioControl';

const SortingPopup = (props) => {
  const onOutsideClick = () => {
    props.updateSorting(internalSortingOrder, internalSortingDirection);
  };

  let internalSortingOrder = props.sortingOrder;
  let internalSortingDirection = props.sortingDirection;

  return (
    <OutsideClickHandler onOutsideClick={onOutsideClick}>
      <div className='sorting-popup'>
        <h4>Sort By:</h4>
        <div className='sorting-options-wrapper'>
          <ul className='sorting-options'>
            {
              props.sortingOptions.map(([value, label]) => {
                return (
                  <li key={value}>
                    <RadioControl
                      id={`${props.chartId}_sort_order_${value}`}
                      value={value}
                      label={label}
                      selected={props.sortingOrder === value}
                      groupName={`${props.chartId}-sort-order`}
                      onChange={(e) => {
                        internalSortingOrder = value;
                      }}
                    >
                    </RadioControl>
                  </li>
                );
              })
            }
          </ul>
          <ul className='sorting-options direction'>
            {
              [
                ['ascending', 'Ascending'],
                ['descending', 'Descending'],
              ].map(([value, label]) => {
                return (
                  <li key={value}>
                    <RadioControl
                      id={`${props.chartId}_sort_direction_${value}`}
                      value={value}
                      label={label}
                      selected={props.sortingDirection === value}
                      groupName={`${props.chartId}-sort-direction`}
                      onChange={(e) => {
                        internalSortingDirection = value;
                      }}
                    >
                    </RadioControl>
                  </li>
                );
              })
            }
          </ul>
        </div>
      </div>
    </OutsideClickHandler>
  );
};

SortingPopup.propTypes = {
  sortingOptions: PropTypes.array.isRequired, //  [['position', 'Default'], ['alphabetical', 'Alphabetical']]
  sortingOrder: PropTypes.string.isRequired,
  sortingDirection: PropTypes.string.isRequired,
  chartId: PropTypes.number,
  updateSorting: PropTypes.func.isRequired,
};

export default SortingPopup;
