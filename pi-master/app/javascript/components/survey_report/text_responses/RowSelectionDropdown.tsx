import React from 'react';

import Popup from './Popup';

interface RowSelectionDropdownProps {
  table: Table
  autotagEnabled: boolean
};

/**
 * A dropdown to help select multiple rows
 *
 * @param {RowSelectionDropdownProps} props
 * @return {JSX.Element}
 */
function RowSelectionDropdown(props: RowSelectionDropdownProps) {
  /**
   * Change selected rows based on selection
   *
   * @param {string} selectEnum
   **/
  function onChangeSelection(selectEnum: string) {
    switch (selectEnum) {
      case 'all':
        props.table.toggleAllRowsSelected(true);
        break;
      case 'tagged':
        props.table.getRowModel().rows.forEach((row) => {
          const hasTags: boolean = row.getValue("appliedTags").length != 0;

          row.toggleSelected(hasTags);
        });
        break;
      case 'untagged':
        props.table.getRowModel().rows.forEach((row) => {
          const hasNoTags: boolean = row.getValue("appliedTags").length == 0;

          row.toggleSelected(hasNoTags);
        });
        break;
      case 'pending':
        props.table.getRowModel().rows.forEach((row) => {
          const pendingApproval: boolean = row.getValue("containsTagPendingApproval");

          row.toggleSelected(pendingApproval);
        });
        break;
      default:
        console.debug('Unrecognized selection', selectEnum);
    }
  }

  return (
    <Popup
      buttonText=''
      triggerElement={<span className='arrow arrow-down'></span>}
    >
      <ul className='row-selection-list tag-status-list'>
        <li>
          <a onClick={() => onChangeSelection('all')}>All</a>
        </li>
        <li>
          <a onClick={() => onChangeSelection('tagged')}>Tagged</a>
        </li>
        <li>
          <a onClick={() => onChangeSelection('untagged')}>Untagged</a>
        </li>
        {
          props.autotagEnabled ?
            <li>
              <a onClick={() => onChangeSelection('pending')} >
                Pending Approval
              </a>
            </li> : null
        }
      </ul>
    </Popup>
  );
}

export default RowSelectionDropdown;
