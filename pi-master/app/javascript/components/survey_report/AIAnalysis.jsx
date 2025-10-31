import React from 'react';
import PropTypes from 'prop-types';

AIAnalysis.propTypes = {
  aiAnalysis: PropTypes.object.isRequired,
};

/**
 * A summary of the last completed survey response analysis
 *
 * @param { AIAnalysisProps } props
 * @return { JSX.Element }
 **/
function AIAnalysis(props) {
  const [showFullSummary, setShowFullSummary] = React.useState(false);

  const summary = () => {
    if (showFullSummary) {
      return props.aiAnalysis.summary;
    } else {
      return props.aiAnalysis.summary.substring(0, 500);
    }
  };

  return (
    <div className='free-text-response-box analysis-box'>
      <h3 className='analysis-header'>
        Analyzed {props.aiAnalysis.datetime}
      </h3>
      <p>{summary()}</p>
      {
        showFullSummary ? null :
          <a
            href='#'
            onClick={(e) => {
              setShowFullSummary(true);
              e.preventDefault();
            }}
          >
            Read more
          </a>
      }
    </div>
  );
}

export default AIAnalysis;
