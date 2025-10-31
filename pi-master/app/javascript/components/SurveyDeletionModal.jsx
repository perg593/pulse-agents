import React from 'react';
import PropTypes from 'prop-types';

import PiModal from './modal_dialog/PiModal';

SurveyDeletionModal.propTypes = {
  archiveSurveyUrl: PropTypes.string.isRequired,
  authenticityToken: PropTypes.string.isRequired,
  deleteSurveyUrl: PropTypes.string.isRequired,
  numAnswers: PropTypes.number.isRequired,
  surveyName: PropTypes.string.isRequired,
};

/**
 * A modal dialog to delete a survey
 * @param { Object } props
 * @return { JSX.Element } the survey deletion modal
*/
function SurveyDeletionModal(props) {
  const [
    confirmationTextMatches,
    setConfirmationTextMatches,
  ] = React.useState(false);

  const handleKeyUp = (e) => {
    const textFieldValue = e.target.value;
    const valuesMatch = textFieldValue === props.surveyName;

    setConfirmationTextMatches(valuesMatch);
  };

  const dialogRef = React.useRef(null);

  const openDialog = () => {
    if (dialogRef.current) {
      dialogRef.current.showModal();
    }
  };

  const closeDialog = () => {
    if (dialogRef.current) {
      dialogRef.current.close();
    }
  };

  React.useEffect(() => {
    openDialog();
  }, []);

  return (
    <>
      <a href='#' onClick={closeDialog} />

      <PiModal
        ref={dialogRef}
        className='survey-deletion-modal'
      >
        <PiModal.Header
          title='Destroy A Survey'
          titleClassName='settings-modal-title'
        />

        <PiModal.Body>
          <p className='deletion-warning'>
            Are you sure you want to destroy this survey?
            This action will also destroy all {props.numAnswers} answers.
            This action cannot be undone.
            <strong>Answers will not be recoverable</strong>.
          </p>

          <p>
            (Note you can also archive, which removes the survey from
            the default view, but preserves answers.)
          </p>

          <p>
            Please type the following to confirm: <strong>{props.surveyName}</strong>
          </p>
          <input onKeyUp={handleKeyUp} size={props.surveyName.length} />
        </PiModal.Body>

        <PiModal.Footer>
          <form
            action={props.archiveSurveyUrl}
            method='POST'
          >
            <input type='hidden' name='_method' value='patch' />
            <input
              type='hidden'
              name='authenticity_token'
              value={props.authenticityToken}
            />
            <button
              className='btn btn-secondary'
              href={props.archiveSurveyUrl}
            >
              Archive survey
            </button>
          </form>

          <form
            action={props.deleteSurveyUrl}
            method='POST'
          >
            <input type='hidden' name='_method' value='delete' />
            <input
              type='hidden'
              name='authenticity_token'
              value={props.authenticityToken}
            />
            <button
              className='btn btn-danger'
              href={props.deleteSurveyUrl}
              disabled={!confirmationTextMatches}
            >
              Yes, destroy survey and answers
            </button>
          </form>

          <button className='btn btn-secondary' onClick={closeDialog}>
            Cancel
          </button>
        </PiModal.Footer>
      </PiModal>
    </>
  );
}

export default SurveyDeletionModal;
