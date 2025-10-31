import React from 'react';

import OutsideClickHandler from 'react-outside-click-handler';

import BulkTagPopup from './BulkTagPopup';
import TickMark from '../../../images/tick.svg';
import CloseMark from '../../../images/close_black_24dp.svg';
import {Tag, UpdatedRowValue} from './Types';
import AddIcon from '../../../images/survey_editor/add.svg';
import {popupPosition} from '../../PopupPositioning';

interface TagCellProps {
  updateTable: (updatedRowValue: UpdatedRowValue) => void
  updateTableBulk: (rows: Array<UpdatedRowValue>) => void
  questionId: number
  getAppliedTags: () => Tag[]
  tagOptions: []
  row: any
  openTagManager: Function
}

/**
 * A table cell for displaying tags applied to a question
 *
 * @param {TagCellProps} props -- see definition above
 * @return {JSX.Element}
 **/
function TagCell(props: TagCellProps) {
  const [showPanel, setShowPanel] = React.useState(false);
  const [panelPosition, setPanelPosition] = React.useState([0, 0]);

  /**
   * Activate the popup panel
   *
   * @param { MouseEvent } e
   */
  function activatePanel(e) {
    setShowPanel(true);
    setPanelPosition(popupPosition(e, 270));
  }

  const appliedTags = props.getAppliedTags();

  interface DeleteAppliedTagButtonProps {
    appliedTagId: number
    questionId: number
    rowIndex: number
    updateTable: (updatedRowValue: UpdatedRowValue) => void
  }

  /**
   * A button to remove an applied tag
   *
   * @param {DeleteAppliedTagButtonProps} props -- see definition above
   * @return {JSX.Element}
   **/
  function DeleteAppliedTagButton(props: DeleteAppliedTagButtonProps) {
    /**
     * Deletes the applied tag on the server and updates the table
     *
     * @param {MouseEvent} event
     */
    function deleteAppliedTag(event: MouseEvent) {
      event.stopPropagation();

      $.ajax({
        url: `/applied_tags/${props.appliedTagId}/remove`,
        data: {question_id: props.questionId},
        method: 'DELETE',
      }).done(function(responseData) {
        console.debug('We did it!');

        const newAppliedTags = [...appliedTags.filter((appliedTag) => {
          return appliedTag.appliedTagId !== props.appliedTagId;
        })];

        props.updateTable({
          rowIndex: props.rowIndex,
          columnId: 'appliedTags',
          value: newAppliedTags,
        });
      }).fail(function(jqXHR, textStatus, errorThrown) {
        console.debug('failed to update! D:', jqXHR, textStatus, errorThrown);
      });
    }

    return (
      <div
        className='control delete'
        onClick={deleteAppliedTag}
      >
        <span
          className='control-icon'
          style={{
            maskImage: `url(${CloseMark})`,
            WebkitMaskImage: `url(${CloseMark})`,
          }}
        />
      </div>
    );
  }

  interface ApproveTagButtonProps {
    appliedTagId: number
    questionId: number
    rowIndex: number
    updateTable: (updatedRowValue: UpdatedRowValue) => void
  }

  /**
   * A button to approve an automatically generated applied tag
   *
   * @param {ApproveTagButtonProps} props -- see definition above
   * @return {JSX.Element}
   **/
  function ApproveTagButton(props: ApproveTagButtonProps) {
    /**
     * Marks the automatically generated tag as approved
     *
     * @param {MouseEvent} event
     */
    function approveTag(event: MouseEvent<HTMLDivElement>) {
      event.stopPropagation();

      $.ajax({
        url: `/applied_tags/${props.appliedTagId}/approve`,
        data: {question_id: props.questionId},
        method: 'PATCH',
      }).done(function(responseData) {
        // update the table
        const newAppliedTags = appliedTags.map((appliedTag) => {
          if (appliedTag.appliedTagId === props.appliedTagId) {
            appliedTag.tagApproved = true;
          }

          return appliedTag;
        });

        props.updateTable({
          rowIndex: props.rowIndex,
          columnId: 'appliedTags',
          value: newAppliedTags
        });
        console.debug('We did it!');
        // updateTheTable(responseData.response);
      }).fail(function(jqXHR, textStatus, errorThrown) {
        console.debug('failed to update! D:', jqXHR, textStatus, errorThrown);
      });
    }

    return (
      <div
        className='control approve'
        onClick={approveTag}
      >
        <span
          className='control-icon'
          style={{
            maskImage: `url(${TickMark})`,
            WebkitMaskImage: `url(${TickMark})`,
          }}
        />
      </div>
    );
  }

  return (
    <>
      <div className='tag-cell'>
        {
          appliedTags !== undefined && appliedTags.length > 0 ?
            appliedTags.map((tag) => {
              return (
                <div key={tag.text}
                  className={`tag-bubble ${tag.tagApproved ? '' : 'pending-approval'}`}
                  style={{
                    backgroundColor: tag.tagColor ?? '#fff',
                  }}
                >
                  <span>{tag.text}</span>
                  {
                    tag.tagApproved ? null :
                      <ApproveTagButton
                        appliedTagId={tag.appliedTagId}
                        questionId={props.questionId}
                        rowIndex={props.row.index}
                        updateTable={props.updateTable}
                      />
                  }
                  <DeleteAppliedTagButton
                    appliedTagId={tag.appliedTagId}
                    questionId={props.questionId}
                    rowIndex={props.row.index}
                    updateTable={props.updateTable}
                  />
                </div>
              );
            }) : null
        }

        <a
          href='#'
          className='big-round-button'
          onClick={activatePanel}
        >
          <img src={AddIcon}/>
        </a>
      </div>

      {
        showPanel ?
          <OutsideClickHandler onOutsideClick={() => setShowPanel(false)} >
            <div className='popup-menu bulk-tag-popup per-row'
              style={{
                left: `${panelPosition[0]}px`,
                top: `${panelPosition[1]}px`,
              }}
            >
              <BulkTagPopup
                tagOptions={props.tagOptions}
                selectedRows={[props.row]}
                questionId={props.questionId}
                updateTableBulk={props.updateTableBulk}
                closePopup={() => setShowPanel(false)}
                openTagManager={props.openTagManager}
              />
            </div>
          </OutsideClickHandler> : null
      }
    </>
  );
}

export default TagCell;
