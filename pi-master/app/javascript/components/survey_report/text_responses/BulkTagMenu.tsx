import React from 'react';

import OutsideClickHandler from 'react-outside-click-handler';

import 'react-tooltip/dist/react-tooltip.css';
import { Tooltip } from 'react-tooltip';

import BulkTagPopup from './BulkTagPopup';

import {UpdatedRowValue} from './Types';

interface BulkTagMenuProps {
  selectedRows: Array<Object>
  tagOptions: TagOption[]
  questionId: number
  updateTableBulk: (rows: Array<UpdatedRowValue>) => void
  disabled: boolean
  openTagManager: Function
}

/**
 * A gmail labelling-style menu for applying and removing tags from answers
 *
 * @param {BulkTagMenuProps} props
 * @return {JSX.Element}
 **/
function BulkTagMenu(props: BulkTagMenuProps) {
  const [showPanel, setShowPanel] = React.useState(false);
  const [panelPosition, setPanelPosition] = React.useState([0, 0]);

  const activatePanel = (e) => {
    setShowPanel(true);
    setPanelPosition([e.clientX, e.clientY]);
  };

  return (
    <>
      <button
        disabled={props.disabled}
        onClick={activatePanel}
        data-tooltip-id='bulk_tag_menu_tooltip'
        data-tooltip-content={props.disabled ? 'Select one or more rows to tag.' : ''}
      >
        Tag Responses
      </button>
      <Tooltip id='bulk_tag_menu_tooltip' />

      {
        showPanel ?
          <div className='outside-click-handler-wrapper'>
            <OutsideClickHandler onOutsideClick={() => setShowPanel(false)} >
              <div
                className='popup-menu bulk-tag-popup'
                style={{
                  left: `${panelPosition[0]}px`,
                  top: `${panelPosition[1]}px`,
                }}
              >
                <BulkTagPopup
                  tagOptions={props.tagOptions}
                  selectedRows={props.selectedRows}
                  questionId={props.questionId}
                  updateTableBulk={props.updateTableBulk}
                  closePopup={() => setShowPanel(false)}
                  openTagManager={props.openTagManager}
                />
              </div>
            </OutsideClickHandler>
          </div> : null
      }
    </>
  );
}

export default BulkTagMenu;
