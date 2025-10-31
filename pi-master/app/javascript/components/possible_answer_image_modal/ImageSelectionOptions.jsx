import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../CollapsiblePanel';

ImageSelectionOptions.propTypes = {
  possibleAnswer: PropTypes.object.isRequired,
  existingImageOptions: PropTypes.array.isRequired,
  node: PropTypes.object,
};

/**
 * Image selection options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function ImageSelectionOptions(props) {
  const [nodeProperties, setNodeProperties] = React.useState({
    answerImageId: props.possibleAnswer.answerImageId || '',

    existingImageOptions: props.existingImageOptions,
  });

  const onNodePropertyChange = (newObject) => {
    setNodeProperties(
        {
          ...nodeProperties,
          ...newObject,
        },
    );

    props.node.updatePossibleAnswer(props.possibleAnswer, newObject);
  };

  const [uploadInProgress, setUploadInProgress] = React.useState(false);

  const [hasError, setHasError] = React.useState(false);

  const uploadAnswerImage = () => {
    const formData = new FormData($('#answer_image_form')[0]);

    setUploadInProgress(true);

    $.ajax({
      url: '/answer_images/',
      data: formData,
      type: 'POST',
      processData: false,
      contentType: false,
    }).done(function(responseData) {
      const newOption = {
        id: responseData.answerImage.id,
        url: responseData.answerImage.url,
      };

      const newExistingImageOptions = [
        ...nodeProperties.existingImageOptions,
        newOption,
      ];

      setNodeProperties(
          {
            ...nodeProperties,
            existingImageOptions: newExistingImageOptions,
          },
      );

      props.node.addPossibleAnswerImageOption(newOption);

      setUploadInProgress(false);

      // now load this info into the options list
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed to upload image', jqXHR, textStatus, errorThrown);

      setUploadInProgress(false);
      setHasError(true);
    });
  };

  const ErrorMessage = () => {
    return (
      <h4>
        We're sorry, but there was a problem uploading your image.
      </h4>
    );
  };

  const ImageOptions = () => {
    if (nodeProperties.existingImageOptions.length === 0 && !uploadInProgress) {
      return null;
    }

    if (hasError) {
      return <ErrorMessage />;
    }

    const options = [...nodeProperties.existingImageOptions].reverse();

    return (
      <>
        <h4>Select an existing image:</h4>
        <ul className='image-selection-list'>
          {
            options.map((existingImageOptions) => {
              const selected = existingImageOptions.id === nodeProperties.answerImageId;

              return (
                <li key={existingImageOptions.id}>
                  <img
                    className={`possible-answer-image ${ selected ? 'selected' : ''}`}
                    src={existingImageOptions.url}
                    onClick={() => onNodePropertyChange({answerImageId: existingImageOptions.id})}
                  />
                </li>
              );
            })
          }
          {
            uploadInProgress ?
              <span>
                Uploading...
              </span> :
              null
          }
        </ul>
      </>
    );
  };

  return (
    <CollapsiblePanel panelTitle='Image Selection'>
      <div className='image-upload-container'>
        <h4 className='image-upload-title'>Upload an image:</h4>
        <form id='answer_image_form'>
          <input
            name='answer_image[image]'
            type="file"
            onChange={uploadAnswerImage}
          />
        </form>
      </div>

      <ImageOptions />
    </CollapsiblePanel>
  );
}

export default ImageSelectionOptions;
