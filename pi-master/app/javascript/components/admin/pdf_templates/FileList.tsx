import React from 'react';

import FileListItem from './FileListItem';
import DraggableFileList from './DraggableFileList';

import {UploadedFile} from './Types';

interface FileListProps {
  files: UploadedFile[]

  enableDragAndDrop?: boolean
  droppableId?: string
  onDelete?: Function
}

/**
 * @param { FileListProps } props -- see interface above
 * @return { JSX.Element }
*/
function FileList(props: FileListProps) {
  const [files, setFiles] = React.useState(props.files);

  if (props.enableDragAndDrop) {
    return <DraggableFileList
      {...props}
      files={files}
      removeFileFromList={removeFileFromList}
    />;
  }

  /**
   * Remove the file with the given ID from the list
   *
   * @param {number} fileId
   **/
  function removeFileFromList(fileId: number) {
    const newFiles = files.filter((file) => file.id !== fileId);

    setFiles(newFiles);
  }

  return (
    <ul className='file-list'>
      {
        files.map((file) => {
          return (
            <FileListItem
              key={file.id}
              file={file}
              removeFileFromList={removeFileFromList}
              onDelete={props.onDelete}
            />
          );
        })
      }
    </ul>
  );
}

export default FileList;
