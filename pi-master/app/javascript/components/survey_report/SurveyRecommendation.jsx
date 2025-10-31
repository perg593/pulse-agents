import React from 'react';
import PropTypes from 'prop-types';
import SurveyRecommendationItem from './SurveyRecommendationItem';

const SurveyRecommendation = ({recommendation}) => {
  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  return (
    <div className="recommendation">
      <div className="timestamp">{formatTimestamp(recommendation.created_at)}</div>

      {recommendation.filters && Object.keys(recommendation.filters).length > 0 && (
        <div className="filters-applied">
          <strong>Filters Applied:</strong> {JSON.stringify(recommendation.filters)}
        </div>
      )}

      <ul className="recommendation-content">
        {
          recommendation.content.map((recommendationItem, index) => ( 
            <SurveyRecommendationItem key={index} recommendationItem={recommendationItem} />
          ))
        }
      </ul>
    </div>
  );
};

SurveyRecommendation.propTypes = {
  recommendation: PropTypes.shape({
    created_at: PropTypes.string,
    filters: PropTypes.object,
    content: PropTypes.array
  }).isRequired
};

export default SurveyRecommendation;
