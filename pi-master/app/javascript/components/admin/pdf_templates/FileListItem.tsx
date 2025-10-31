import React from 'react';

import DeleteButton from '../../DeleteButton';

import {UploadedFile} from './Types';
import AuthenticityTokenContext from './AuthenticityTokenContext';

interface FileListItemProps {
  file: UploadedFile
  removeFileFromList: Function
  onDelete: Function
}

/**
 * @param { FileListItemProps } props -- see interface above
 * @return { JSX.Element }
*/
function FileListItem(props: FileListItemProps) {
  const authenticityToken = React.useContext(AuthenticityTokenContext);
  const downloadUrl = new URL(
      `admin/pdf_template_file_uploads/?id=${props.file.id}`,
      window.location.origin,
  ).href;

  /**
   * @param {number} pdfTemplateFileUploadId
   */
  function deleteFile(pdfTemplateFileUploadId: number) {
    const url = new URL(
        'admin/pdf_template_file_uploads/',
        window.location.origin,
    );

    fetch(
        url,
        {
          method: 'DELETE',
          body: JSON.stringify({
            id: pdfTemplateFileUploadId.toString(),
            authenticity_token: authenticityToken,
          }),
          headers: {'Content-Type': 'application/json'},
        },
    ).then((response) => {
      if (response.ok) {
        props.removeFileFromList(pdfTemplateFileUploadId);

        if (props.onDelete) {
          props.onDelete(response.body);
        }
      }
    });
  }

  return (
    <li
      className='file-list-item'
      key={props.file.id}
      ref={props.innerRef}
      {...props.provided?.draggableProps}
      {...props.provided?.dragHandleProps}
    >
      <a href={downloadUrl} target='_blank'>{ props.file.name }</a>

      <DeleteButton
        onClick={() => {
          if (confirm(`Delete ${props.file.name} from S3?`) == true) {
            deleteFile(props.file.id);
          }
        }}
      />
    </li>
  );
}

export default FileListItem;
