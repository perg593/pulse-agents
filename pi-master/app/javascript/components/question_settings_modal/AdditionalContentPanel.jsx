import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../CollapsiblePanel';

import RichTextEditor from './RichTextEditor';
import WidgetListItem from '../survey_edit_sidebar/WidgetListItem';

import AboveIcon from '../../images/survey_editor/widget_positions/inline_above.png';
import BelowIcon from '../../images/survey_editor/widget_positions/inline_below.png';
import BetweenIcon from '../../images/survey_editor/widget_positions/inline_inside.png';

import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

AdditionalContentPanel.propTypes = {
  engine: PropTypes.object.isRequired, // The react-diagrams DiagramEngine
  node: PropTypes.object.isRequired, // The QuestionNode
};

/**
 * The additional text options panel
 * @param { Object } props -- see propTypes
 * @return { JSX.Element } the panel
*/
function AdditionalContentPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    showAdditionalContent: props.node.question.showAdditionalContent,
    additionalContent: props.node.question.additionalContent || '',
    additionalContentPosition: props.node.question.additionalContentPosition || props.node.defaultValue('additionalContentPosition'),
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  const widgets = [
    {
      value: 'header',
      icon: AboveIcon,
      label: 'Header',
      onChange: (e) => {
        onQuestionPropertyChange({additionalContentPosition: e.target.value});
      },
      name: 'additional_content_position',
    },
    {
      value: 'between',
      icon: BetweenIcon,
      label: 'Between',
      onChange: (e) => {
        onQuestionPropertyChange({additionalContentPosition: e.target.value});
      },
      name: 'additional_content_position',
    },
    {
      value: 'footer',
      icon: BelowIcon,
      label: 'Footer',
      onChange: (e) => {
        onQuestionPropertyChange({additionalContentPosition: e.target.value});
      },
      name: 'additional_content_position',
    },
  ];

  const showAdditionalContentId = `${props.node.question.id}_show_additional_content`;

  return (
    <CollapsiblePanel panelTitle='Additional Content'>
      <div className='options-row'>
        <label htmlFor={showAdditionalContentId} className='full-width'>
          Show additional content:
        </label>
        <input
          id={showAdditionalContentId}
          type="checkbox"
          onChange={(e) => {
            onQuestionPropertyChange({showAdditionalContent: e.target.checked});
          }}
          value={questionProperties.showAdditionalContent}
          checked={questionProperties.showAdditionalContent}
        />
      </div>
      <div className='options-row'>
        <RichTextEditor
          engine={props.engine}
          node={props.node}
          questionProperties={questionProperties}
          onQuestionPropertyChange={onQuestionPropertyChange}
          questionPropertyName="additionalContent"
        />
      </div>
      <div className='options-row'>
        <h4>Position relative to question:</h4>
      </div>
      <div className='options-row'>
        <ul className='sidebar-widgets-list short-list'>
          {
            widgets.map((widget) => {
              return <WidgetListItem
                key={widget.value}
                widget={widget}
                value={questionProperties.additionalContentPosition}
              />;
            })
          }
        </ul>
      </div>
    </CollapsiblePanel>
  );
}

export default AdditionalContentPanel;
