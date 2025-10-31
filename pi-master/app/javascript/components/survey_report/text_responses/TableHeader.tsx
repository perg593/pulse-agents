import React from 'react';

import {DragDropContext, Droppable, Draggable} from '@hello-pangea/dnd';

import {
  ColumnOrderState,
  flexRender,
} from '@tanstack/react-table';

import Filter from './Filter';
import ResizeHandle from './ResizeHandle';
import SortingIndicator from './SortingIndicator';
import {newColumnOrder} from './ColumnReordering';

interface TableHeaderProps {
  headerGroups: HeaderGroup[]
  columnOrder: ColumnOrderState
  tagOptions: TagOption[]
  autotagEnabled: boolean
  setColumnOrder: Function
  visibleColumns: Column[]
};

/**
 * Renders the table header
 * Supports drag-and-drop headers for column reordering
 *
 * @param { TableHeaderProps } props -- see TableHeaderProps
 * @return { JSX.Element }
 **/
function TableHeader(props: TableHeaderProps) {
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
    // 0 corresponds to the checkbox column
    if ([0, undefined].includes(destinationIndex)) {
      return;
    }

    props.setColumnOrder(
        newColumnOrder(
            props.columnOrder,
            props.visibleColumns,
            dragUpdateObj.draggableId,
            destinationIndex,
        ),
    );
  }

  return (
    <DragDropContext
      onDragEnd={(dragUpdateObj) => handleColumnDrop(dragUpdateObj)}
    >
      <thead>
        {props.headerGroups.map((headerGroup, headerGroupIndex) => (
          <Droppable
            key={headerGroupIndex}
            droppableId="droppable"
            direction="horizontal"
          >
            {(droppableProvided, snapshot) => (
              <tr
                key={headerGroup.id}
                ref={droppableProvided.innerRef}
              >
                {
                  headerGroup.headers.map((header, index) => (
                    <Draggable
                      key={header.id}
                      draggableId={header.id}
                      index={index}
                      isDragDisabled={header.column.columnDef.meta.dragDisabled ?? false}
                    >
                      {(provided, snapshot) => {
                        return (
                          <th
                            key={header.id}
                            className={`${header.id}-column`}
                            style={{
                              width: header.column.columnDef.meta.resizeDisabled ? null : header.getSize(),
                              position: 'relative',
                            }}
                          >
                            <div
                              {...provided.draggableProps}
                              {...provided.dragHandleProps}
                              ref={provided.innerRef}
                            >
                              <div className='header-content'>
                                <div
                                  className='header-container'
                                  onClick={header.column.getToggleSortingHandler()}
                                >
                                  {
                                    header.isPlaceholder ? null :
                                      flexRender(
                                          header.column.columnDef.header,
                                          header.getContext(),
                                      )
                                  }

                                  {
                                    header.column.columnDef.meta.sortingDisabled ? null :
                                      <SortingIndicator column={header.column}/>
                                  }
                                </div>
                                {
                                  header.column.getCanFilter() ? (
                                    <div>
                                      <Filter
                                        column={header.column}
                                        tagOptions={props.tagOptions}
                                        autotagEnabled={props.autotagEnabled}
                                      />
                                    </div>
                                  ) : null
                                }
                              </div>
                            </div>
                            <ResizeHandle header={header} />
                          </th>
                        );
                      }}
                    </Draggable>
                  ))}
              </tr>
            )}
          </Droppable>
        ))}
      </thead>
    </DragDropContext>
  );
}

export default TableHeader;
