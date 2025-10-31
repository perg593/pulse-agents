import React from 'react';

import {Droppable, Draggable} from '@hello-pangea/dnd';

import {UploadedFile} from './Types';
import FileListItem from './FileListItem';

interface DraggableFileListProps {
  files: UploadedFile[]
  droppableId: string
  removeFileFromList: Function
}

/**
 * @param { DraggableFileListProps } props -- see interface above
 * @return { JSX.Element }
 **/
function DraggableFileList(props: DraggableFileListProps) {
  return (
    <Droppable droppableId={props.droppableId}>
      {(droppableProvided) => (
        <ul
          className='file-list'
          ref={droppableProvided.innerRef}
          {...droppableProvided.droppableProps}
        >
          {
            props.files.map((file, index) => (
              <Draggable
                key={file.id}
                draggableId={file.id.toString()}
                index={index}
              >
                {(provided, snapshot) => (
                  <FileListItem
                    innerRef={provided.innerRef}
                    file={file}
                    provided={provided}
                    removeFileFromList={props.removeFileFromList}
                  />
                )}
              </Draggable>
            ))
          }
          {droppableProvided.placeholder}
        </ul>
      )}
    </Droppable>
  );
}

export default DraggableFileList;
