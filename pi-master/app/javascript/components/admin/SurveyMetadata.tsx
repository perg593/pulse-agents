import React from 'react';

import EditableField from '../qrvey_dashboard_mappings/EditableField';
import Otter from './Otter';
import OtterImage from '../../images/otters/otter_programmer.jpg';

type Metadatum = {
  id: number
  name: string
}

type Survey = {
  id: number
  name: string
  metadatum: Metadatum
  questions: Array<Question>
}

type Question = {
  id: number
  content: string
  metadatum: Metadatum
  possibleAnswers: Array<PossibleAnswer>
}

type PossibleAnswer = {
  id: number
  content: string
  metadatum: Metadatum
}

interface SurveyMetadataProps {
  survey: Survey
  authenticityToken: string
};

interface DeleteButtonProps {
  metadatumId: number
}
interface SurveyWrapperProps {
  survey: Survey
}
interface QuestionWrapperProps {
  question: Question
}
interface PossibleAnswerWrapperProps {
  possibleAnswer: PossibleAnswer
}

/**
 * @param { SurveyMetadataProps } props -- see interface above
 * @return { JSX.Element }
*/
function SurveyMetadata(props: SurveyMetadataProps) {
  const [survey, setSurvey] = React.useState(props.survey);

  /**
   * Creates a Metadata record with the given name and owner
   *
   * @param { number } ownerId - the ID of the owner
   * @param { string } name - the metaname
   * @param { string } type - the type
   **/
  function createMetaname(ownerId: number, name: string, type: string) {
    const url = new URL('/admin/metadata', window.location.origin);

    fetch(
        url,
        {
          method: 'POST',
          body: JSON.stringify({
            name: name,
            owner_record_id: ownerId.toString(),
            type: type,
            authenticity_token: props.authenticityToken,
          }),
          headers: {'Content-Type': 'application/json'},
        },
    );
  }

  /**
   * Updates a Metadatum's name
   *
   * @param { number } metaDatumId - the ID of the record
   * @param { string } newName - the new metaname
   **/
  function updateMetaname(metaDatumId: number, newName: string) {
    const url = new URL('/admin/metadata', window.location.origin);

    fetch(
        url,
        {
          method: 'PATCH',
          body: JSON.stringify({
            id: metaDatumId.toString(),
            authenticity_token: props.authenticityToken,
            metadatum: {
              name: newName,
            },
          }),
          headers: {'Content-Type': 'application/json'},
        },
    );
  }

  /**
   * Delete the record's metadatum
   *
   * @param { number } metaDatumId - the ID of the record
   *
   **/
  function destroyMetadatum(metaDatumId: number) {
    const url = new URL('/admin/metadata', window.location.origin);

    fetch(
        url,
        {
          method: 'DELETE',
          body: JSON.stringify({
            id: metaDatumId.toString(),
            authenticity_token: props.authenticityToken,
          }),
          headers: {'Content-Type': 'application/json'},
        },
    ).then((response) => {
      if (response.ok) {
        const newSurvey = {...survey};

        if (newSurvey.metadatum?.id === metaDatumId) {
          newSurvey.metadatum = null;
        }

        newSurvey.questions.forEach((question) => {
          if (question.metadatum?.id === metaDatumId) {
            question.metadatum = null;
          }

          question.possibleAnswers.forEach((possibleAnswer) => {
            if (possibleAnswer.metadatum?.id === metaDatumId) {
              possibleAnswer.metadatum = null;
            }
          });
        });

        setSurvey(newSurvey);
      }
    });
  }

  /**
   * A button to delete a Metadatum record
   *
   * @param { number } metaDatumId - the ID of the record
   * @return { JSX.Element }
   **/
  function DeleteButton({metadatumId}: DeleteButtonProps) {
    return (
      <button onClick={() => destroyMetadatum(metadatumId)}>
        DELETE
      </button>
    );
  }

  /**
   * A survey's details
   *
   * @param { Survey } survey
   * @return { JSX.Element }
   **/
  function SurveyWrapper({survey}: SurveyWrapperProps) {
    return (
      <div className='survey-wrapper'>
        <h2>Survey ({survey.id})&quot;{survey.name}&quot;</h2>
        <p>
          <span>Metaname:</span>
          <EditableField
            initialValue={survey.metadatum?.name ?? 'NONE'}
            persistentUpdate={(newValue) => {
              if (survey.metadatum) {
                updateMetaname(survey.metadatum.id, newValue);
              } else {
                createMetaname(survey.id, newValue, 'survey');
              }
            }}
          />
          {
            survey.metadatum ?
              <DeleteButton metadatumId={survey.metadatum.id} /> : null
          }
        </p>

        {
          survey.questions.map((question) => {
            return <QuestionWrapper key={question.id} question={question} />;
          })
        }
      </div>
    );
  }

  /**
   * A question's details
   *
   * @param { Question } question
   * @return { JSX.Element }
   */
  function QuestionWrapper({question}: QuestionWrapperProps) {
    return (
      <div className='question-wrapper'>
        <h3>Question ({question.id})&quot;{question.content}&quot;</h3>
        <p>
          <span>Metaname:</span>
          <EditableField
            initialValue={question.metadatum?.name ?? 'NONE'}
            persistentUpdate={(newValue) => {
              if (question.metadatum) {
                updateMetaname(question.metadatum.id, newValue);
              } else {
                createMetaname(question.id, newValue, 'question');
              }
            }}
          />
          {
            question.metadatum ?
              <DeleteButton metadatumId={question.metadatum.id} /> : null
          }
        </p>

        {
          question.possibleAnswers.map((possibleAnswer) => {
            return (
              <PossibleAnswerWrapper
                key={possibleAnswer.id}
                possibleAnswer={possibleAnswer}
              />
            );
          })
        }
      </div>
    );
  }

  /**
   * A possible answer's details
   *
   * @param { Object } possibleAnswer - the possible answer
   * @return { JSX.Element }
   */
  function PossibleAnswerWrapper({possibleAnswer}: PossibleAnswerWrapperProps) {
    return (
      <div className='possible-answer-wrapper'>
        <h4>Possible Answer ({possibleAnswer.id})&quot;{possibleAnswer.content}&quot;</h4>
        <p>
          <span>Metaname:</span>
          <EditableField
            initialValue={possibleAnswer.metadatum?.name ?? 'NONE'}
            persistentUpdate={(newValue) => {
              if (possibleAnswer.metadatum) {
                updateMetaname(possibleAnswer.metadatum.id, newValue);
              } else {
                createMetaname(possibleAnswer.id, newValue, 'possible_answer');
              }
            }}
          />
          {
            possibleAnswer.metadatum ?
              <DeleteButton metadatumId={possibleAnswer.metadatum.id} /> : null
          }
        </p>
      </div>
    );
  }

  return (
    <>
      <h1>Survey Metadata Editor</h1>
      {
        <h2>
          { survey === undefined ? 'Please provide a survey ID' : null }
        </h2>
      }

      <Otter image={OtterImage} title="It pays the bills -- Otto" />

      <form>
        <label htmlFor='survey_id_field'>Survey ID</label>
        <input
          id='survey_id_field'
          type='text'
          name='survey_id'
          placeholder='Survey ID'
          defaultValue={survey?.id}
          required
        />
        <input
          className='pi-primary-button'
          type='submit'
          value='Load Survey'
        />
      </form>

      {
        survey ? <SurveyWrapper survey={survey} /> : null
      }
    </>
  );
}

export default SurveyMetadata;
