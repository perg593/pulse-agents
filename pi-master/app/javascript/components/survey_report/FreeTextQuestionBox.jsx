import React from 'react';
import PropTypes from 'prop-types';

import tinycolor from 'tinycolor2';

import AIAnalysis from './AIAnalysis';
import SettingsIcon from './SettingsIcon';
import SparklesIcon from '../../images/sparkles.svg';
import Spinner from '../Spinner.jsx';

FreeTextQuestionBox.propTypes = {
  includeAIAnalysis: PropTypes.bool.isRequired,
  aiAnalysis: PropTypes.object,
  numResponses: PropTypes.number.isRequired,
  question: PropTypes.object.isRequired,
  responseSample: PropTypes.array.isRequired,
  title: PropTypes.string.isRequired,
  tags: PropTypes.array,
};

/**
 *
 * Renders a report box for a free text question
 * TODO:
 *   - Pipes leading out of question
 *
 * @param { FreeTextQuestionBoxProps } props
 * @return { JSX.Element }
 **/
function FreeTextQuestionBox(props) {
  // TODO: Make constants
  // response-sample
  // tag-frequency-chart
  const [activePanel, setActivePanel] = React.useState('response-sample');
  const [aiSummarizationJobId, setAiSummarizationJobId] = React.useState(null);
  const [dynamicAnalysis, setDynamicAnalysis] = React.useState(null);

  const aiAnalysis = dynamicAnalysis || props.aiAnalysis;

  const FreeTextQuestionControls = () => {
    /**
     * Request an AI summary of the free text responses
     **/
    function requestAISummary() {
      $.ajax({
        url: '/ai_summarization_jobs',
        data: {
          ai_summarization_job: {
            question_id: props.question.id,
          },
        },
        method: 'POST',
      }).done(function(responseData) {
        setAiSummarizationJobId(responseData.id);
      }).fail(function(jqXHR, textStatus, errorThrown) {
        const errorMessage = jqXHR.responseJSON.error;

        console.debug(
            'Failed to request analysis!',
            jqXHR,
            textStatus,
            errorThrown,
        );
        alert(`Failed to request analysis! ${errorMessage}`);
      });
    }

    return (
      <div className='settings-control-container'>
        <button
          className='settings-control'
          onClick={requestAISummary}
          title='Request AI analysis'
        >
          { aiSummarizationJobId ? <Spinner /> : <SettingsIcon icon={SparklesIcon} /> }
        </button>
      </div>
    );
  };

  const Header = () => {
    const headerContent = () => {
      const title = props.title.toUpperCase();

      const groupedResponseCount = new Intl.NumberFormat().format(props.numResponses);

      const responseSummary = `${title} (${groupedResponseCount} responses)`;

      return responseSummary;
    };

    /**
     * Request the backend for analysis updates
     */
    function requestStatusUpdate() {
      $.ajax({
        url: `/ai_summarization_jobs/${aiSummarizationJobId}`,
      }).done(function(responseData) {
        if (responseData.status === 'done') {
          setDynamicAnalysis({
            datetime: responseData.datetime,
            summary: responseData.summary,
          });
          setAiSummarizationJobId(null);
        }
      }).fail(function(jqXHR, textStatus, errorThrown) {
        console.debug('error!', jqXHR, textStatus, errorThrown);
      });
    }

    /**
     * Begin regular polling for analysis updates
     * @return {number} The interval ID
     **/
    function beginPolling() {
      const pollingInterval = 3000;

      return setInterval(requestStatusUpdate, pollingInterval);
    }

    React.useEffect(() => {
      let intervalId = null;

      if (aiSummarizationJobId !== null) {
        intervalId = beginPolling();
      }

      return () => {
        clearInterval(intervalId);
      };
    }, [aiSummarizationJobId]);

    return (
      <div className='question-header'>
        <h3
          className='chart-header'
          id={`question-line-anchor-${props.question.id}`}
        >
          { headerContent() }
        </h3>

        { props.includeAIAnalysis ? <FreeTextQuestionControls /> : null }
      </div>
    );
  };

  const FreeTextResponseBox = () => {
    return (
      <div className='free-text-response-box'>
        <h3 className='response-header'>
          {props.responseSample.length} Most Recent Responses
        </h3>
        {
          props.responseSample.map((response, i) => {
            return (
              <p key={i}>{response}</p>
            );
          })
        }
      </div>
    );
  };

  const TagByFrequencyChart = () => {
    return (
      <div>
        {
          props.tags.map((tag, i) => {
            const percent = (i / props.tags.length) * 100;
            const darkBlue = tinycolor('#1A537E');
            const backgroundColor = darkBlue.brighten(percent).toString();

            return (
              <React.Fragment key={i}>
                <h4>{tag.name}</h4>
                <div className='result-bar-wrapper'>
                  <div
                    className='result-bar'
                    style={{
                      width: `${tag.rate}%`,
                      backgroundColor: backgroundColor,
                    }}
                  >
                  </div>
                  <div className='answer-rate'>
                    {tag.count} ({tag.rate}%)
                  </div>
                </div>
              </React.Fragment>
            );
          })
        }
      </div>
    );
  };

  const tagDataAvailable = props.tags.length > 0;

  return (
    <div className='question'>
      <Header/>

      {
        props.includeAIAnalysis && aiAnalysis ?
          <AIAnalysis aiAnalysis={aiAnalysis} /> : null
      }

      {
        activePanel === 'response-sample' ? <FreeTextResponseBox /> :
          <TagByFrequencyChart />
      }

      <div className='action-container'>
        <a
          className='link-button'
          href={`/questions/${props.question.id}/text_responses${location.search}`}
        >
          View All Responses
        </a>

        {
          activePanel === 'response-sample' ?
            <button
              className='link-button'
              onClick={() => setActivePanel('tag-frequency-chart')}
              disabled={!tagDataAvailable}
              title={tagDataAvailable ? '' : 'No data yet'}
            >
              Tag By Frequency Chart
            </button> :
              <button
                className='link-button'
                onClick={() => setActivePanel('response-sample')}
              >
                Response Sample
              </button>
        }
      </div>

    </div>
  );
}

export default FreeTextQuestionBox;
