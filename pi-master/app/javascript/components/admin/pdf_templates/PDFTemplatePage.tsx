import React from 'react';

import FileUploadForm from './FileUploadForm';
import FileList from './FileList';
import StaticPages from './StaticPages';

import {UploadedFile} from './Types';

import Otter from '../Otter';
import OtterImage from '../../../images/otters/otter_template.jpg';

import AuthenticityTokenContext from './AuthenticityTokenContext';

interface PDFTemplatePageProps {
  survey: Survey,
  templateFile: UploadedFile,
  assetFiles: UploadedFile[],
  staticPdfFiles: UploadedFile[],
  authenticityToken: string,
};

type Survey = {
  name: string
  id: number
}

/**
 * @param { PDFTemplatePageProps } props -- see interface above
 * @return { JSX.Element }
*/
function PDFTemplatePage(props: PDFTemplatePageProps) {
  return (
    <AuthenticityTokenContext.Provider value={props.authenticityToken}>
      <h1>PDF Template for {props.survey.name}</h1>

      <Otter image={OtterImage} title="What's PDF stand for again? -- Otto" />

      <h2>Upload</h2>
      <FileUploadForm surveyId={props.survey.id}/>

      {
        props.templateFile ?
          <div className='preview-button-container'>
            <a
              href={`/admin/surveys/preview?survey_id=${props.survey.id}`}
              target='_blank'
              className='pi-secondary-button'
            >
              Preview
            </a>

            <a
              href={`/admin/surveys/html_preview?survey_id=${props.survey.id}`}
              target='_blank'
            >
              HTML Preview
            </a>
          </div> : null
      }

      <div>
        <h2>Template</h2>
        <FileList files={props.templateFile ? [props.templateFile] : []}/>
      </div>

      <div>
        <h2>Assets</h2>
        <FileList files={props.assetFiles}/>
      </div>

      <div>
        <h2>Static Pages</h2>
        <StaticPages staticPageFiles={props.staticPdfFiles}/>
      </div>
    </AuthenticityTokenContext.Provider>
  );
}

export default PDFTemplatePage;
