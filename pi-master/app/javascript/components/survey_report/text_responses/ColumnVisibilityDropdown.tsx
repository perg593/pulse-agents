import React from 'react';

import {DragDropContext, Droppable, Draggable} from '@hello-pangea/dnd';
import {ColumnOrderState} from '@tanstack/react-table';

import {newColumnOrder} from './ColumnReordering';

import Popup from './Popup';

interface ColumnVisibilityDropdownProps {
  columnOptions: () => Column<any, unknown>[]
  columnOrder: ColumnOrderState
  setColumnOrder: Function
}

/**
 * A dropdown menu to toggle rendering of table columns
 *
 * @param {ColumnVisibilityDropdownProps} props
 * @return {JSX.Element}
 **/
function ColumnVisibilityDropdown(props: ColumnVisibilityDropdownProps) {
  /**
   * Handle column drop
   *
   * @param {Object} dragUpdateObj - see the library's online documentation:
   *   https://github.com/hello-pangea/dnd
   **/
  function handleColumnDrop(dragUpdateObj) {
    if (dragUpdateObj.reason !== 'DROP') {
      return;
    }

    const destinationIndex = dragUpdateObj.destination?.index;

    // This can happen if you drop outside of the droppable area
    if (destinationIndex === undefined) {
      return;
    }

    props.setColumnOrder(
        newColumnOrder(
            props.columnOrder,
            props.columnOptions(),
            dragUpdateObj.draggableId,
            destinationIndex,
        ),
    );
  }

  return (
    <Popup
      additionalClasses='column-selection-menu'
      buttonText='Select Columns'
    >
      <DragDropContext
        onDragEnd={(dragUpdateObj) => handleColumnDrop(dragUpdateObj)}
      >
        <Droppable
          key={'column-visibility-droppable'}
          droppableId="droppable"
        >
          {(droppableProvided, snapshot) => (
            <ul
              className='checkbox-list'
              ref={droppableProvided.innerRef}
            >
              {
                props.columnOptions().map((column, index) => {
                  return (
                    <Draggable
                      key={column.id}
                      draggableId={column.id}
                      index={index}
                    >
                      {(provided, snapshot) => {
                        return (
                          <li
                            {...provided.draggableProps}
                            {...provided.dragHandleProps}
                            key={column.id}
                            ref={provided.innerRef}
                            className='draggable'
                          >
                            <label>
                              <input
                                type='checkbox'
                                checked={column.getIsVisible()}
                                onChange={column.getToggleVisibilityHandler()}
                              />
                              {column.columnDef.meta.titleized}
                            </label>
                          </li>
                        );
                      }}
                    </Draggable>
                  );
                })
              }
            </ul>
          )}
        </Droppable>
      </DragDropContext>
    </Popup>
  );
}

export default ColumnVisibilityDropdown;
