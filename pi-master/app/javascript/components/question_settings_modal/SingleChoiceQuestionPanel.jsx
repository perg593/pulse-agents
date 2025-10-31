import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation} from '../NumberValidations';

import CollapsiblePanel from '../CollapsiblePanel';
import AdditionalTextPanel from './AdditionalTextPanel';
import AdditionalContentPanel from './AdditionalContentPanel';
import StandardButtonsIcon from '../../images/survey_editor/standard_buttons.svg';
import RadioButtonsIcon from '../../images/survey_editor/radio_buttons.svg';
import MenuButtonsIcon from '../../images/survey_editor/menu_buttons.svg';
const alignmentImages = require.context('../../images/survey_editor/answer_alignments');

import RadioButtonProperties from './RadioButtonProperties';
import AnswerOrderPanel from './AnswerOrderPanel';

import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

AnswerOptionsPanel.propTypes = {
  node: PropTypes.object.isRequired,
};

/**
 * The general answer options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function AnswerOptionsPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    answersPerRowMobile: props.node.question.answersPerRowMobile,
    answersPerRowDesktop: props.node.question.answersPerRowDesktop,
    singleChoiceDefaultLabel: props.node.question.singleChoiceDefaultLabel || props.node.defaultValue('singleChoiceDefaultLabel'),
    desktopWidthType: props.node.question.desktopWidthType || 'fixed',
    answersAlignmentDesktop: props.node.question.answersAlignmentDesktop || 'left',
    mobileWidthType: props.node.question.mobileWidthType || 'fixed',
    answersAlignmentMobile: props.node.question.answersAlignmentMobile || 'left',
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  const ButtonProperties = () => {
    switch (props.node.question.buttonType) {
      case 'standard':
        return <StandardButtonProperties />;
      case 'radio':
        return (
          <RadioButtonProperties
            questionProperties={questionProperties}
            onQuestionPropertyChange={onQuestionPropertyChange}
          />
        );
      case 'menu':
        return <MenuButtonProperties />;
      default:
        console.debug('Unrecognized button type: ', props.node.question.buttonType);
        return null;
    }
  };

  const widthOptions = [
    {
      label: 'Fixed width buttons',
      value: 'fixed',
    },
    {
      label: 'Variable width buttons',
      value: 'variable',
    },
  ];

  const answersAlignmentOptions = [
    {
      label: 'Aligned left',
      value: 'left',
    },
    {
      label: 'Aligned center',
      value: 'center',
    },
    {
      label: 'Aligned right',
      value: 'right',
    },
    {
      label: 'Spaced between',
      value: 'space_between',
    },
    {
      label: 'Spaced around',
      value: 'space_around',
    },
    {
      label: 'Spaced evenly',
      value: 'space_evenly',
    },
  ];

  const AlignmentDescription = (props) => {
    const imageName = `./${props.widthValue}-${props.alignment.replace('_', '-')}.png`;
    let image = null;

    try {
      image = alignmentImages(imageName);
    } catch (error) {
      console.error(error);
    }

    let description = null;

    switch (props.alignment) {
      case 'space_around':
        description = 'Items have equal space around them.';
        break;
      case 'space_between':
        description = 'Items are evenly distributed.';
        break;
      case 'space_evenly':
        description = 'The spacing between any two items is equal.';
        break;
    }

    return (
      <div className='alignment-description-container'>
        { image ? <img src={image} /> : null }
        { description ? <span className='alignment-description'>{description}</span> : null }
      </div>
    );
  };

  AlignmentDescription .propTypes = {
    alignment: PropTypes.string.isRequired,
    widthValue: PropTypes.string.isRequired,
  };

  const AlignmentOptions = ({type}) => {
    const camelCaseType = `${type[0].toUpperCase()}${type.substr(1)}`;

    const widthType = `${type}WidthType`;
    const answersPerRow = `answersPerRow${camelCaseType}`;
    const answersAlignment = `answersAlignment${camelCaseType}`;

    return (
      <>
        <div className='options-row'>
          <h4>{camelCaseType}</h4>
        </div>
        <div className='options-row'>
          <select
            value={questionProperties[widthType]}
            onChange={
              (e) => {
                const updatedProperty = {};
                updatedProperty[widthType] = e.target.value;
                onQuestionPropertyChange(updatedProperty);
              }
            }
          >
            {
              widthOptions.map((option) => {
                return (
                  <option
                    key={option.value}
                    value={option.value}
                  >
                    {option.label}
                  </option>
                );
              })
            }
          </select>

          {
            questionProperties[widthType] === 'fixed' ?
              <>
                <NumberFormat
                  className='number-input'
                  value={questionProperties[answersPerRow]}
                  thousandSeparator={false}
                  decimalSeparator={null}
                  allowNegative={false}
                  isAllowed={(values) => {
                    return minValidation(values, 1);
                  }}
                  onBlur={
                    (e) => {
                      const updatedProperty = {};
                      updatedProperty[answersPerRow] = e.target.value;
                      onQuestionPropertyChange(updatedProperty);
                    }
                  }
                />
                <span className='field-description'>Answer(s) per row</span>
              </> :
                null
          }

          <select
            value={questionProperties[answersAlignment]}
            onChange={
              (e) => {
                const updatedProperty = {};
                updatedProperty[answersAlignment] = e.target.value;
                onQuestionPropertyChange(updatedProperty);
              }
            }
          >
            {
              answersAlignmentOptions.map((option) => {
                return (
                  <option
                    key={option.value}
                    value={option.value}
                  >
                    {option.label}
                  </option>
                );
              })
            }
          </select>
        </div>
        <div className='options-row'>
          <AlignmentDescription
            widthValue={questionProperties[widthType]}
            alignment={questionProperties[answersAlignment]}
          />
        </div>
      </>
    );
  };
  AlignmentOptions.propTypes = {
    type: PropTypes.string.isRequired,
  };

  const StandardButtonProperties = () => {
    return (
      <>
        <AlignmentOptions type='desktop' />
        <AlignmentOptions type='mobile' />
      </>
    );
  };

  const MenuButtonProperties = () => {
    return (
      <div className='options-row'>
        <label htmlFor='menu'>Default Label</label>
        <input
          id='menu'
          className='single-choice-default-label-field'
          placeholder='Select an option'
          defaultValue={questionProperties.singleChoiceDefaultLabel}
          onBlur={(e) => {
            onQuestionPropertyChange({singleChoiceDefaultLabel: e.target.value});
          }}
        />
      </div>
    );
  };

  return (
    <CollapsiblePanel panelTitle='Answer Options'>
      <ButtonProperties />
    </CollapsiblePanel>
  );
}

ButtonStylePanel.propTypes = {
  onChange: PropTypes.func.isRequired,
  buttonType: PropTypes.string.isRequired,
};

/**
 * The button style options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function ButtonStylePanel(props) {
  const OptionsList = () => {
    return (
      <ul className='button-options-list'>
        {
          [
            {buttonType: 'standard', label: 'Standard Button', icon: StandardButtonsIcon},
            {buttonType: 'radio', label: 'Radio Button', icon: RadioButtonsIcon},
            {buttonType: 'menu', label: 'Menu', icon: MenuButtonsIcon},
          ].map((option) => {
            return (
              <li key={option.buttonType}>
                <label
                  htmlFor={`${option.buttonType}_button`}
                >
                  <img src={option.icon}/>
                  {option.label}
                </label>
                <input
                  type='radio'
                  name='button-style'
                  id={`${option.buttonType}_button`}
                  value={option.buttonType}
                  onChange={props.onChange}
                  checked={props.buttonType === option.buttonType}
                />
              </li>
            );
          })
        }
      </ul>
    );
  };

  return (
    <CollapsiblePanel panelTitle='Button Style'>
      <OptionsList />
    </CollapsiblePanel>
  );
}

SingleChoiceQuestionPanel.propTypes = {
  node: PropTypes.object.isRequired,
  engine: PropTypes.object.isRequired,
  lockPossibleAnswerOrderRandomization: PropTypes.bool.isRequired,
};

/**
 * The options for single choice question question settings modals.
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function SingleChoiceQuestionPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    buttonType: props.node.question.buttonType,
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  const randomizationOptions = [
    {
      label: 'All responses',
      value: 0,
    },
    {
      label: 'All responses, except the last',
      value: 1,
    },
  ];

  return (
    <>
      <AnswerOrderPanel
        node={props.node}
        randomizationOptions={randomizationOptions}
        lockPossibleAnswerOrderRandomization={props.lockPossibleAnswerOrderRandomization}
      />
      <ButtonStylePanel
        buttonType={questionProperties.buttonType}
        onChange={(e) => onQuestionPropertyChange({buttonType: e.target.value})}
      />
      <AnswerOptionsPanel
        buttonType={questionProperties.buttonType}
        node={props.node}
      />
      {
        questionProperties.buttonType == 'standard' ?
          <AdditionalTextPanel node={props.node} /> :
          null
      }
      <SingleChoiceOptionsPanel node={props.node} />
      <AdditionalContentPanel node={props.node} engine={props.engine} />
    </>
  );
}

SingleChoiceOptionsPanel.propTypes = {
  node: PropTypes.object.isRequired,
};

/**
 * The single choice question options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function SingleChoiceOptionsPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    emptyErrorText: props.node.question.emptyErrorText || props.node.defaultValue('emptyErrorText'),
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  return (
    <CollapsiblePanel panelTitle='Single Choice Options'>
      <div className='options-row'>
        <label
          htmlFor='empty_error_text'
          className='full-width'
          title='Display when the user attempts to submit with no answer selected'
        >
          Empty Error Text:
        </label>
        <input
          id='empty_error_text'
          className='single-choice-empty-error-text'
          value={questionProperties.emptyErrorText}
          title='Display when the user attempts to submit with no answer selected'
          onChange={(e) => {
            onQuestionPropertyChange({emptyErrorText: e.target.value});
          }}
        />
      </div>
    </CollapsiblePanel>
  );
}

export default SingleChoiceQuestionPanel;
