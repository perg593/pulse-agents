import React from 'react';

import Popup from './Popup';

interface ColumnGroupingMenuProps {
  columns: () => Column<any, unknown>[]
}

/**
 * A dropdown menu to toggle grouping of table columns
 *
 * @param {ColumnGroupingMenuProps} props
 * @return {JSX.Element}
 **/
function ColumnGroupingMenu(props: ColumnGroupingMenuProps) {
  const groupableColumns = () => {
    return props.columns().filter((column) => {
      const columnMetadata = column.columnDef.meta;
      const columnIsGroupable = !columnMetadata.groupingDisabled;

      return columnIsGroupable;
    });
  };

  return (
    <Popup
      buttonText='Group'
      additionalClasses='column-selection-menu'
    >
      <ul className='checkbox-list'>
        {
          groupableColumns().map((column) => {
            return (
              <li key={column.id}>
                <label>
                  <input
                    type='checkbox'
                    checked={column.getIsGrouped()}
                    onChange={column.getToggleGroupingHandler()}
                  />
                  {column.columnDef.meta.titleized}
                </label>
              </li>
            );
          })
        }
      </ul>
    </Popup>
  );
}

export default ColumnGroupingMenu;
