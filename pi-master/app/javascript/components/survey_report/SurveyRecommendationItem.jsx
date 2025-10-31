import React from 'react';
import PropTypes from 'prop-types';

const SurveyRecommendationItem = ({recommendationItem}) => {
  return (
    <li className="recommendation-item">
      <h4 className="recommendation-title">{recommendationItem.title}</h4>
      <p className="recommendation-reasoning">{recommendationItem.reasoning}</p>
      <p className="recommendation-benefit">{recommendationItem.expectedBenefit}</p>
      <p className="recommendation-question">{recommendationItem.question}</p>
      <p className="recommendation-answers">{recommendationItem.possibleAnswers.join(', ')}</p>
      <div className="recommendation-targeting">
        <span className="targeting-label">Suggested Targeting: </span>
        <span>{recommendationItem.targeting}</span>
      </div>
    </li>
  );
};

SurveyRecommendationItem.propTypes = {
  recommendationItem: PropTypes.shape({
    title: PropTypes.string,
    reasoning: PropTypes.string,
    expectedBenefit: PropTypes.string,
    question: PropTypes.string,
    possibleAnswers: PropTypes.arrayOf(PropTypes.string),
    targeting: PropTypes.string
  }).isRequired
};

export default SurveyRecommendationItem;
