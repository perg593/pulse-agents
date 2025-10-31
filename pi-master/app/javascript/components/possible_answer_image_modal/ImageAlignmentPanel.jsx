import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../CollapsiblePanel';

ImageAlignmentPanel.propTypes = {
  node: PropTypes.object,
  possibleAnswer: PropTypes.object.isRequired,
};
/**
 * Image alignment options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function ImageAlignmentPanel(props) {
  const [nodeProperties, setNodeProperties] = React.useState({
    imageSettings: props.node.question.imageSettings || '',
    imagePositionCd: props.possibleAnswer.imagePositionCd || '',
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

  const onNodeQuestionPropertyChange = (newObject) => {
    setNodeProperties(
        {
          ...nodeProperties,
          ...newObject,
        },
    );

    props.node.updateQuestion(newObject);
  };

  const ImageAlignmentOptions = () => {
    return (
      <>
        <ul>
          <li className='options-row'>
            <label htmlFor='image_only'>Image only</label>
            <input
              type='radio'
              name='image_settings'
              id='image_only'
              value='image_only'
              checked={nodeProperties.imageSettings === 'image_only'}
              onChange={(e) => onNodeQuestionPropertyChange({imageSettings: 'image_only'})}
            />
          </li>
          <li className='options-row'>
            <label htmlFor='text_and_image'>Text and image</label>
            <input
              type='radio'
              name='image_settings'
              id='text_and_image'
              value='text_and_image'
              checked={nodeProperties.imageSettings === 'text_and_image'}
              onChange={(e) => onNodeQuestionPropertyChange({imageSettings: 'text_and_image'})}
            />
          </li>
        </ul>
        {
          // nodeProperties.imageSettings === 'text_and_image' ?
          //   <ul className='image-position-wrapper'>
          //     {
          //       ['top', 'bottom', 'left', 'right'].map((imagePosition) => {
          //         const checked = nodeProperties.imagePositionCd === imagePosition;
          //
          //         return (
          //           <li
          //             key={imagePosition}
          //             className={`${imagePosition} ${checked ? 'checked' : ''}`}
          //           >
          //             <label htmlFor={imagePosition}>
          //               <div className='sample-box'/>
          //               <span className='sample-text'>ABC</span>
          //             </label>
          //             <input
          //               type='radio'
          //               name='image_position_cd'
          //               id={imagePosition}
          //               value={imagePosition}
          //               checked={checked}
          //               onChange={(e) => onNodePropertyChange({imagePositionCd: imagePosition})}
          //             />
          //           </li>
          //         );
          //       })
          //     }
          //   </ul> :
          //     null
        }
      </>
    );
  };

  return (
    <CollapsiblePanel panelTitle='Image Alignment Options'>
      <ImageAlignmentOptions
        node={props.node}
        possibleAnswer={props.possibleAnswer}
      />
    </CollapsiblePanel>
  );
}

export default ImageAlignmentPanel;
