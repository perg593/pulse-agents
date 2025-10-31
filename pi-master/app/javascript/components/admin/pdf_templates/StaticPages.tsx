import React from 'react';
import {DragDropContext} from '@hello-pangea/dnd';

import FileList from './FileList';

import {UploadedFile} from './Types';

import AuthenticityTokenContext from './AuthenticityTokenContext';

interface StaticPagesProps {
  staticPageFiles: UploadedFile[],
};

/**
 * A component for managing and arranging static PDF files that will be appended
 * or prepended to the final PDF.
 *
 * @param { StaticPagesProps } props -- see interface above
 * @return { JSX.Element }
**/
function StaticPages(props: StaticPagesProps) {
  const [beforeTemplateFiles, setBeforeTemplateFiles] = React.useState(props.staticPageFiles.filter((file) => {
    return file.position < 0;
  }));

  const [afterTemplateFiles, setAfterTemplateFiles] = React.useState(props.staticPageFiles.filter((file) => {
    return file.position > 0;
  }));

  const authenticityToken = React.useContext(AuthenticityTokenContext);

  /**
   * Update position properties
   *
   * @param {FileUpload[]} newBeforeTemplateFiles
   * @param {FileUpload[]} newAfterTemplateFiles
   *
   * @return {FileUpload[]}
   **/
  function updatePositions(newBeforeTemplateFiles, newAfterTemplateFiles) {
    newBeforeTemplateFiles.forEach((file, i) => {
      file.position = (newBeforeTemplateFiles.length - i) * -1;
    });

    newAfterTemplateFiles.forEach((file, i) => {
      file.position = i + 1;
    });

    return [beforeTemplateFiles, afterTemplateFiles];
  }

  /**
   * Reorder files on server
   *
   * @param {UploadedFile[]} staticFiles
   */
  function reorderRemotely(staticFiles: UploadedFile[]) {
    const files = staticFiles.map((file, i) => {
      return {
        id: file.id,
        position: file.position,
      };
    });

    fetch(
        '/admin/pdf_template_file_uploads/reorder_static_pdf_files',
        {
          method: 'PATCH',
          body: JSON.stringify({
            authenticity_token: authenticityToken,
            files: files,
          }),
          headers: {'Content-Type': 'application/json'},
        },
    ).then((response) => {
      if (response.ok) {
        console.debug("Reordered on the server. Reordering locally");
      } else {
        alert('Sorry, reordering failed');
      }
    });
  }

  /**
   * Calculates new file order for this page
   *
   * @param {UploadedFile[]} sourceList
   * @param {UploadedFile[]} destinationList
   * @param {number} sourceIndex
   * @param {number} destinationIndex
   *
   * @return {Array}
   **/
  function reorderLocally(
    sourceList: UploadedFile[],
    destinationList: UploadedFile[],
    sourceIndex: number,
    destinationIndex: number
  ) {
    const movedFile = sourceList[sourceIndex];
    sourceList.splice(sourceIndex, 1); // remove it from source list

    destinationList.splice(destinationIndex, 0, movedFile);

    return [beforeTemplateFiles, afterTemplateFiles];
  }

  return (
    <>
      <DragDropContext
        onDragEnd={(dragUpdateObj) => {
          if (dragUpdateObj.reason === 'DROP') {
            if (!dragUpdateObj.destination) {
              return;
            }

            const sourceIndex = dragUpdateObj.source.index;
            const destinationIndex = dragUpdateObj.destination.index;

            const sourceDroppableId = dragUpdateObj.source.droppableId;
            const destinationDroppableId = dragUpdateObj.destination.droppableId;

            if (sourceIndex != destinationIndex || sourceDroppableId != destinationDroppableId) {
              const sourceList = sourceDroppableId === 'beforeTemplateFiles' ? beforeTemplateFiles : afterTemplateFiles;
              const destinationList = destinationDroppableId === 'beforeTemplateFiles' ? beforeTemplateFiles : afterTemplateFiles;

              const [
                newBeforeTemplateFiles, newAfterTemplateFiles,
              ] = reorderLocally(
                  sourceList,
                  destinationList,
                  sourceIndex,
                  destinationIndex,
              );

              updatePositions(newBeforeTemplateFiles, newAfterTemplateFiles);

              setBeforeTemplateFiles(newBeforeTemplateFiles);
              setAfterTemplateFiles(newAfterTemplateFiles);

              reorderRemotely([...newBeforeTemplateFiles, ...newAfterTemplateFiles]);
            }
          }
        }}
      >
        <h3>Before template</h3>
        <FileList
          files={beforeTemplateFiles}
          enableDragAndDrop={true}
          droppableId="beforeTemplateFiles"
          onDelete={(newFiles) => {
            setBeforeTemplateFiles(newFiles);
          }}
        />

        <h3>After template</h3>
        <FileList
          files={afterTemplateFiles}
          enableDragAndDrop={true}
          droppableId="afterTemplateFiles"
          onDelete={(newFiles) => {
            setAfterTemplateFiles(newFiles);
          }}
        />
      </DragDropContext>
    </>
  );
}

export default StaticPages;
