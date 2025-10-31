import React from 'react';

import FileList from './FileList';
import AuthenticityTokenContext from './AuthenticityTokenContext';

interface FileUploadFormProps {
  surveyId: number,
};

/**
 * @param { FileUploadFormProps } props -- see interface above
 * @return { JSX.Element }
 **/
function FileUploadForm(props: FileUploadFormProps) {
  const [stagedFiles, setStagedFiles] = React.useState([]);

  const authenticityToken = React.useContext(AuthenticityTokenContext);

  return (
    <form
      method='post'
      encType='multipart/form-data'
      action='/admin/pdf_template_file_uploads/upload'
    >
      <input
        type='hidden'
        name='survey_id'
        value={props.surveyId}
      />
      <input
        type='hidden'
        name='authenticity_token'
        value={authenticityToken}
      />

      <input
        type="file"
        name='files[]'
        multiple
        onChange={(e) => {
          const files = [];

          for (let i = 0; i < e.target.files.length; i++) {
            files.push(e.target.files[i]);
          }

          setStagedFiles(files);
        }}
      />

      <FileList files={stagedFiles} />

      {
        stagedFiles.length > 0 ?
          <button
            disabled={stagedFiles.length == 0}
            className='pi-primary-button'
            type="submit"
          >
            Upload
          </button> : null
      }
    </form>
  );
}

export default FileUploadForm;
