import React from 'react';
import PropTypes from 'prop-types';

import SettingsModal from './SettingsModal';

import ImageAlignmentPanel from '../possible_answer_image_modal/ImageAlignmentPanel';
import ImageDimensionsPanel from '../possible_answer_image_modal/ImageDimensionsPanel';
import ImageSelectionOptions from '../possible_answer_image_modal/ImageSelectionOptions';

import ImageIcon from '../../images/survey_editor/image_alt.svg';

PossibleAnswerImageModal.propTypes = {
  node: PropTypes.object,
  engine: PropTypes.object,
  possibleAnswer: PropTypes.object.isRequired,
  existingImageOptions: PropTypes.array.isRequired,
  readOnly: PropTypes.bool,
};
/**
 * The possible answer image options modal
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function PossibleAnswerImageModal(props) {
  const [showPreviewPopup, setShowPreviewPopup] = React.useState(false);

  const possibleAnswerImagePreview = () => {
    if (!props.possibleAnswer.answerImageId) {
      return null;
    }

    const selectedImage = props.existingImageOptions.find((imageOption) => {
      return props.possibleAnswer.answerImageId === imageOption.id;
    });

    return (
      <div className='possible-answer-image-preview'>
        <h4 className='possible-answer-image-preview-header'>Existing Image</h4>
        <img
          className='possible-answer-image-preview-image'
          src={selectedImage?.url}
        />
      </div>
    );
  };

  const modalTrigger = () => {
    return (
      <span
        style={{
          maskImage: `url(${ImageIcon})`,
          WebkitMaskImage: `url(${ImageIcon})`,
        }}
        className={`possible-answer-image-modal-trigger ${props.possibleAnswer.answerImageId ? 'image-selected' : ''}`}
        onMouseOver={() => setShowPreviewPopup(true)}
        onMouseLeave={() => setShowPreviewPopup(false)}
        onClick={() => setShowPreviewPopup(false)}
      />
    );
  };

  return (
    <>
      {
        props.readOnly ? modalTrigger() :
          <SettingsModal
            engine={props.engine}
            modalTrigger={modalTrigger()}
            node={props.node}
          >
            <ImageSelectionOptions
              node={props.node}
              possibleAnswer={props.possibleAnswer}
              existingImageOptions={props.existingImageOptions}
            />
            <ImageAlignmentPanel
              node={props.node}
              possibleAnswer={props.possibleAnswer}
            />
            <ImageDimensionsPanel
              node={props.node}
              possibleAnswer={props.possibleAnswer}
            />
          </SettingsModal>
      }
      { showPreviewPopup ? possibleAnswerImagePreview() : null }
    </>
  );
}

export default PossibleAnswerImageModal;
