import React from 'react';

import ArrowUp from '../../../images/survey_dashboard/arrow_up.svg';
import ArrowDown from '../../../images/survey_dashboard/arrow_down.svg';

interface SortingIndicatorProps {
  column: Column<any, unknown>
}

/**
 * Lets the user know how a column is being sorted
 *
 * @param { SortingIndicatorProps } props -- see SortingIndicatorProps
 * @return {JSX.Element}
 **/
function SortingIndicator(props: SortingIndicatorProps) {
  const sortingDirection = props.column.getIsSorted() as string;

  if (sortingDirection === undefined) {
    return null;
  } else {
    return (
      <img
        className="sorting-indicator"
        src={sortingDirection === 'desc' ? ArrowDown : ArrowUp}
      >
      </img>
    );
  }
}

export default SortingIndicator;
