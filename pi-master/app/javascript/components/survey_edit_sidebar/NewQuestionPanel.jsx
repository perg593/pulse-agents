import React from 'react';
import PropTypes from 'prop-types';

import OutsideClickHandler from 'react-outside-click-handler';

import DisabledFeaturesContext from '../survey_editor/DisabledFeaturesContext';

import SliderIcon from '../../images/survey_editor/slider.png';
import NpsIcon from '../../images/survey_editor/nps.png';
import CustomContentIcon from '../../images/survey_editor/custom_content.png';
import FreeTextIcon from '../../images/survey_editor/free_text.png';
import MultipleChoiceIcon from '../../images/survey_editor/multiple_choice.png';
import SingleChoiceIcon from '../../images/survey_editor/single_choice.png';
import AddIcon from '../../images/survey_editor/add.svg';

NewQuestionPanel.propTypes = {
  addQuestionHandler: PropTypes.func.isRequired,
  addInvitationHandler: PropTypes.func.isRequired,
  includeInvitation: PropTypes.func.isRequired,
};

/**
 * The new question panel that pops up when you click "+"
 * @param { Object } props
 * @return { JSX.Element } - the panel
*/
function NewQuestionPanel(
    {addQuestionHandler, addInvitationHandler, includeInvitation},
) {
  const disableQuestionAddition = React.useContext(DisabledFeaturesContext).readOnly;
  const [showNewQuestionPanel, setShowNewQuestionPanel] = React.useState(false);

  const createNode = (nodeType, details) => {
    switch (nodeType) {
      case 'question':
        addQuestionHandler(details);
        break;
      case 'invitation':
        addInvitationHandler();
        break;
      default:
        console.debug('Unrecognized node type', nodeType);
    }

    setShowNewQuestionPanel(false);
  };

  const questionTypes = [
    {
      type: 'nps',
      icon: NpsIcon,
      label: 'NPS',
    },
    {
      type: 'custom_content',
      icon: CustomContentIcon,
      label: 'CUSTOM CONTENT',
    },
    {
      type: 'slider',
      icon: SliderIcon,
      label: 'SLIDER',
    },
    {
      type: 'free_text',
      icon: FreeTextIcon,
      label: 'FREE TEXT',
    },
    {
      type: 'multiple_choice',
      icon: MultipleChoiceIcon,
      label: 'MULTI CHOICE',
    },
    {
      type: 'single_choice',
      icon: SingleChoiceIcon,
      label: 'SINGLE CHOICE',
    },
  ];

  return (
    <div className={`new-question-option-wrapper ${showNewQuestionPanel ? 'open' : ''}`}>
      {
        showNewQuestionPanel ?
          <OutsideClickHandler
            onOutsideClick={() => setShowNewQuestionPanel(false)}
          >
            <div className='new-question-panel-wrapper'>
              <div className='new-question-panel'>
                {
                  disableQuestionAddition ? null :
                    <div className='new-question-type-wrapper'>
                      <h1>QUESTION TYPE</h1>
                      <ul>
                        {
                          questionTypes.map((data) => {
                            return (
                              <li key={data.type}>
                                <a
                                  className='big-round-button icon-wrapper'
                                  onClick={() => createNode('question', data.type)}
                                  href='#'
                                >
                                  <img src={data.icon}/>
                                </a>
                                <span className='icon-label'>{data.label}</span>
                              </li>
                            );
                          })
                        }
                      </ul>
                    </div>
                }

                {
                  includeInvitation() ?
                    <div className='invitation-container'>
                      <a
                        className='big-round-button icon-wrapper'
                        onClick={() => createNode('invitation')}
                        href='#'
                      >
                        <img src={NpsIcon}/>
                      </a>
                      <span className='icon-label'>INVITATION</span>
                    </div> :
                       null
                }

              </div>
              <div className='arrow-right'></div>
            </div>
          </OutsideClickHandler> :
            null
      }
      <a
        href='#'
        className='big-round-button new-question-button'
        onClick={() => setShowNewQuestionPanel(!showNewQuestionPanel)}
      >
        <img src={AddIcon}/>
      </a>
    </div>
  );
}

export default NewQuestionPanel;
