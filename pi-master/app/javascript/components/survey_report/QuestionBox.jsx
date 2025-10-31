import React from 'react';
import PropTypes from 'prop-types';

import {activeStates, sortPossibleAnswers} from './Common';
import PossibleAnswer from './PossibleAnswer';

import TrendReport from './TrendReport';

import Pipe from './Pipe';
import BarChartSettings from './BarChartSettings';

const QuestionBox = (props) => {
  const [internalChart, setInternalChart] = React.useState(null);

  // ('content, 'answer_count', 'position'[default])
  const [possibleAnswerSortingOrder, setPossibleAnswerSortingOrder] =
    React.useState('position');
  // ('ascending', 'descending')
  const [possibleAnswerSortingDirection, setPossibleAnswerSortingDirection] =
    React.useState('ascending');

  // A simple switch to toggle when we want to force an update of the pipes.
  // Pipes rely on the rendered positions of the source
  // (a possible answer anchor) and target (question box), so they can't
  // be updated in the usual React way.
  const [updatePipe, setUpdatePipe] = React.useState(false);

  const orderedPossibleAnswers = () => {
    const possibleAnswers = [...props.possibleAnswers];
    return sortPossibleAnswers(possibleAnswers, possibleAnswerSortingOrder, possibleAnswerSortingDirection);
  };

  const viewFullScreen = () => {
    const chart = internalChart;
    internalChart.fullscreen.open();
    setInternalChart(chart); // TODO: Investigate why internalChart becomes empty after going back and forth between Bar chart button and Stack chart button
  };

  const downloadImage = () => {
    const chart = internalChart;
    internalChart.exportChart();
    setInternalChart(chart); // TODO: Investigate why internalChart becomes empty after going back and forth between Bar chart button and Stack chart button
  };

  const Header = () => {
    const headerContent = () => {
      const title = props.title.toUpperCase();

      const groupedResponseCount = new Intl.NumberFormat().format(props.numResponses);
      const ungroupedResponseCount = new Intl.NumberFormat().format(props.numUngroupedResponses);

      let responseSummary = `${title} (${groupedResponseCount} responses)`;

      if (props.numResponses !== props.numUngroupedResponses) {
        responseSummary = `${responseSummary} (${ungroupedResponseCount} answers captured)`;
      }

      return responseSummary;
    };

    const sortingOptions = [['position', 'Default'], ['alphabetical', 'Alphabetical'], ['answer_count', 'Number of Responses']];

    return (
      <div className='question-header'>
        <h3
          className='chart-header'
          id={`question-line-anchor-${props.question.id}`}
        >
          { headerContent() }
        </h3>
        <BarChartSettings
          viewFullScreen={viewFullScreen}
          downloadImage={downloadImage}
          chartId={props.chartId}
          sortingOptions={sortingOptions}
          sortingOrder={possibleAnswerSortingOrder}
          sortingDirection={possibleAnswerSortingDirection}
          updateSorting={(newOrder, newDirection) => {
            setPossibleAnswerSortingOrder(newOrder);
            setPossibleAnswerSortingDirection(newDirection);
            setUpdatePipe(!updatePipe);
          }}
          legend={
            orderedPossibleAnswers().map((possibleAnswer) => { // TODO: DRY off with PageEvent
              return {
                id: possibleAnswer.id,
                name: possibleAnswer.content,
                color: props.newColors[possibleAnswer.id],
                colorUpdateUrl: possibleAnswer.colorUpdateUrl,
              };
            })
          }
          updateColor={props.updateColor}
        />
      </div>
    );
  };

  const answersClass = () => {
    const activeClass = props.possibleAnswers.some((possibleAnswer) => {
      return possibleAnswer.id === props.activePossibleAnswerId;
    }) ? 'answers-active' : '';

    return `answers ${activeClass}`;
  };

  /**
   * Returns the Common.activeStates value for a possible answer
   * @param {number} possibleAnswerId
   * @return {activeStates} the Common.activeStates for that possible answer
   **/
  function getActiveState(possibleAnswerId) {
    if (possibleAnswerId === props.activePossibleAnswerId) {
      return activeStates.active;
    }

    const siblingIsActive = props.possibleAnswers.some((possibleAnswer) => {
      return possibleAnswer.id === props.activePossibleAnswerId;
    });

    if (siblingIsActive) {
      return activeStates.inactive;
    }

    return activeStates.default;
  }

  const renderPipes = () => {
    return orderedPossibleAnswers().map((possibleAnswer) => {
      const nextQuestionId = possibleAnswer.nextQuestionId ||
        props.question.nextQuestionId;

      if (!nextQuestionId || !props.nextQuestionVisible(nextQuestionId)) {
        return null;
      }

      return (
        <Pipe
          key={`pipe_possible_answer_${possibleAnswer.id}`}
          sourceId={`possible-answer-anchor-${possibleAnswer.id}`}
          targetId={`question-line-anchor-${nextQuestionId}`}
          laneIndex={props.lanesForRouting(nextQuestionId)}
          colorOverride={props.newColors[possibleAnswer.id] || possibleAnswer.color}
          force={updatePipe || props.updatePipes}
        />
      );
    });
  };

  return (
    <>
      <div className='question'>
        <Header/>
        <div className={answersClass()}>
          {
            orderedPossibleAnswers().map((possibleAnswer) => {
              return (
                <PossibleAnswer
                  key={possibleAnswer.content}
                  question={props.question}
                  possibleAnswer={possibleAnswer}
                  activeState={getActiveState(possibleAnswer.id)}
                  handlePossibleAnswerSelection={props.handlePossibleAnswerSelection}
                  newColors={props.newColors}
                />
              );
            })
          }
        </div>
        <TrendReport
          seriesData={props.seriesData}
          newColors={props.newColors}
          chartId={props.chartId}
          setInternalChart={setInternalChart}
          dataLastUpdatedAt={props.dataLastUpdatedAt}
        />
        <div className='action-container'>
          <button
            className='link-button'
            onClick={viewFullScreen}
          >
            View Full Screen
          </button>
          <button
            className='link-button'
            onClick={downloadImage}
          >
            Download Image
          </button>
        </div>
      </div>
      { renderPipes() }
    </>
  );
};

QuestionBox.propTypes = {
  possibleAnswers: PropTypes.array.isRequired,
  question: PropTypes.object.isRequired,
  handlePossibleAnswerSelection: PropTypes.func.isRequired,
  activePossibleAnswerId: PropTypes.number,
  newColors: PropTypes.object.isRequired,
  numResponses: PropTypes.number.isRequired,
  numUngroupedResponses: PropTypes.number.isRequired,
  title: PropTypes.string.isRequired,
  chartId: PropTypes.number.isRequired,
  updateColor: PropTypes.func.isRequired,
  seriesData: PropTypes.array.isRequired,
  nextQuestionVisible: PropTypes.func.isRequired,
  lanesForRouting: PropTypes.func.isRequired,
  updatePipes: PropTypes.bool,
};

export default QuestionBox;
