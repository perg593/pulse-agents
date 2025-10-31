import React from 'react';

import SettingsIcon from '../SettingsIcon';
import TickIcon from '../../../images/tick.svg';

interface AiTagRecommendationProps {
    aiTagNameRecommendation: string
    createTag: Function
};

/**
 * A cell that represents a tag name recommended by AI shown inside TagManager
 *
 * @param {AiTagRecommendationProps} props
 * @return {JSX.Element}
 **/
function AiTagRecommendation(props: AiTagRecommendationProps) {
  const [promotedToTag, setPromotedToTag] = React.useState(false);

  return (
    <li className='ai-recommended-tag'>
      <div className='name'>{props.aiTagNameRecommendation}</div>
      <button
        className={'promote' + (promotedToTag ? ' promoted' : '')}
        disabled={promotedToTag}
        onClick={ () => {
          props.createTag(props.aiTagNameRecommendation);
          setPromotedToTag(true);
        }} >
        {promotedToTag ? <SettingsIcon icon={TickIcon}/> : <span>+</span>}
      </button>
    </li>
  );
}

export default AiTagRecommendation;
