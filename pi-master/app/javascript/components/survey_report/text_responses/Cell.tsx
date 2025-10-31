import React from 'react';

import {flexRender} from '@tanstack/react-table';

import ArrowUp from '../../../images/survey_dashboard/caret_open.svg';
import ArrowDown from '../../../images/survey_dashboard/caret_closed.svg';

interface CellProps {
  cell: Object // TODO: Be more specific
  row: Object // TODO: Be more specific
};

/**
 * @param {CellProps} props
 * @return { JSX.Element }
 **/
function Cell(props: CellProps) {
  if (props.cell.getIsGrouped()) {
    return (
      <>
        <button
          {...{
            onClick: props.row.getToggleExpandedHandler(),
            style: {
              cursor: props.row.getCanExpand() ? 'pointer' : 'normal',
            },
          }}
        >
          <img
            className="folding-arrow-icon"
            src={ props.row.getIsExpanded() ? ArrowUp : ArrowDown }
          />
          {flexRender(props.cell.column.columnDef.cell, props.cell.getContext())}
          ({props.row.subRows.length})
        </button>
      </>
    );
  } else if (props.cell.getIsAggregated()) {
    return flexRender(props.cell.column.columnDef.aggregatedCell ?? props.cell.column.columnDef.cell, props.cell.getContext());
  } else if (props.cell.getIsPlaceholder()) {
    return null;
  } else {
    return flexRender(props.cell.column.columnDef.cell, props.cell.getContext());
  }
}

export default Cell;
