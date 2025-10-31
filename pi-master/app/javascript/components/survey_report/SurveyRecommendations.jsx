import React, {useEffect, useState} from 'react';
import PropTypes from 'prop-types';
import SurveyRecommendationsChannel from '../../channels/survey_recommendations_channel';
import SurveyRecommendation from './SurveyRecommendation';
import Spinner from '../Spinner';
import CollapsiblePanel from '../CollapsiblePanel';

const SurveyRecommendations = (props) => {
  const [recommendations, setRecommendations] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchRecommendations = () => {
    fetch(`/surveys/${props.surveyId}/recommendations.json`)
      .then(response => response.json())
      .then(setRecommendations)
      .catch(error => setError(error.message));
  };

  useEffect(() => {
    fetchRecommendations();

    const newSubscription = SurveyRecommendationsChannel.subscribe(props.surveyId, {
      received: (data) => {
        setIsLoading(false);

        if (data.error) {
          setError(data.error);
          return;
        }

        setRecommendations((prevRecommendations) => [data, ...prevRecommendations]);
      }
    });

    return () => newSubscription?.unsubscribe();
  }, []);

  const generateRecommendations = () => {
    setIsLoading(true);
    setError(null);

    const searchParams = new URLSearchParams(window.location.search).toString();

    fetch(`/surveys/${props.surveyId}/recommendations?${searchParams}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        authenticity_token: props.authenticityToken,
      })
    });
  };

  const eligibleForRecommendations = () => {
    return props.answerCount >= 10;
  };

  return (
    <CollapsiblePanel
      panelTitle="Next Insights"
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
    >
      <div className="survey-recommendations">
        <div className="button-container">
        {eligibleForRecommendations() ? (
          <button 
            className="pi-primary-button recommendation-generation-button"
            onClick={generateRecommendations}
            disabled={isLoading}
          >
            <span className="recommendation-generation-button-text">
              {isLoading ? 'GENERATING' : 'GET RECOMMENDATIONS'}
            </span>
            {isLoading ? <Spinner className="recommendation-spinner" /> : null}
          </button>
        ) : (
          <p className="insufficient-data-message">
            Not enough data to generate recommendations (minimum 10 answers required)
          </p>
        )}
      </div>

      { error ? (<p className="error-message">{error}</p>) : null }

      <div className="recommendations-container">
          {
            recommendations.map((recommendation) => (
              <SurveyRecommendation key={recommendation.id} recommendation={recommendation} />
            ))
          }
        </div>
      </div>
    </CollapsiblePanel>
  );
};

SurveyRecommendations.propTypes = {
  surveyId: PropTypes.number,
  authenticityToken: PropTypes.string,
  answerCount: PropTypes.number.isRequired,
  panelExpansionSettings: PropTypes.object,
  updatePanelExpansionSettings: PropTypes.func,
};

export default SurveyRecommendations;
