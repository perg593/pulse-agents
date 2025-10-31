import React from 'react';
import PropTypes from 'prop-types';

import domtoimage from 'dom-to-image';

import {sortPossibleAnswers} from './Common';
import BarChartSettings from './BarChartSettings';

const PageEvent = (props) => {
  const [selectedQuestion, setSelectedQuestion] = React.useState(props.selectedQuestion);
  const [selectedEvent, setSelectedEvent] = React.useState(props.selectedEvent);

  const [possibleAnswerSortingOrder, setPossibleAnswerSortingOrder] = React.useState('position'); // ('content, 'answer_count', 'position'[default])
  const [possibleAnswerSortingDirection, setPossibleAnswerSortingDirection] = React.useState('ascending'); // ('ascending', 'descending')

  const [newColors, setNewColors] = React.useState(() => {
    const updatedColors = {};
    selectedQuestion.possibleAnswers.forEach((possibleAnswer) => {
      updatedColors[possibleAnswer.id] = possibleAnswer.color;
    });
    return updatedColors;
  });

  const [fullScreenEnabled, setFullScreenEnabled] = React.useState(false); // NOTE: Not used yet. See React.useEffect that toggles "full-screen" class

  React.useEffect(() => {
    const fullScreenChangeEvents = ['fullscreenchange', 'webkitfullscreenchange', 'mozfullscreenchange', 'MSFullscreenChange'];
    const chart = document.getElementById('page-event-chart-body');

    fullScreenChangeEvents.forEach((event) => {
      chart.addEventListener(event, function() {
        chart.classList.toggle('full-screen'); // TODO: Remove this line after commenting out the below line
        // setFullScreenEnabled(!fullScreenEnabled); // TODO: Investigate why fullscreen event exits immediately with this line
      }, false);
    });
  });

  const averageEventAnswerRate = () => {
    if (selectedQuestion.possibleAnswers.length == 0) {
      return 0;
    } else {
      const eventAnswerRateSum = selectedQuestion.possibleAnswers.reduce((sum, possibleAnswer) => sum + possibleAnswer.eventAnswerRate, 0);
      return Math.round( eventAnswerRateSum / selectedQuestion.possibleAnswers.length);
    }
  };

  const relativeEventAnswerRate = (eventAnswerRate) => {
    const averageRate = averageEventAnswerRate();
    if (averageRate === 0) {
      return 0;
    }
    return Math.round((Math.abs(eventAnswerRate - averageRate)) * 100 / averageRate);
  };

  const relativeEventAnswerRateLabel = (eventAnswerRate) => {
    const relativeRate = relativeEventAnswerRate(eventAnswerRate);
    if (relativeRate === 0) {
      return 'equal to average';
    }
    return `${relativeRate}% ${eventAnswerRate > averageEventAnswerRate() ? 'higher' : 'lower'} than average`;
  };

  const changeFromAverageRate = (eventAnswerRate) => {
    const changeRate = relativeEventAnswerRate(eventAnswerRate);
    if (changeRate === 0) {
      return '0%';
    }
    return `${eventAnswerRate > averageEventAnswerRate() ? '+' : '-'}${changeRate}%`; // E.g. +93%, -58%
  };

  const totalEventAnswerCount = () => selectedQuestion.possibleAnswers.reduce((sum, possibleAnswer) => sum + possibleAnswer.eventAnswerCount, 0);

  const updateSelectedQuestion = (e) => { // TODO: Simplify the logic by isolating possibleAnswers from selectedQuestion
    const questionId = e.target.value;
    const selectedItemParams = `question_id=${questionId}&page_event_name=${selectedEvent.name}`;
    const successCallback = (result) => {
      setSelectedQuestion(result);
      const updatedColors = {};
      result.possibleAnswers.forEach((possibleAnswer) => {
        updatedColors[possibleAnswer.id] = possibleAnswer.color;
      });
      setNewColors(updatedColors);
    };
    updateSelectedItems(selectedItemParams, successCallback);
    addSelectedItemToCurrentUrl('question_id', questionId);
  };

  const updateSelectedEvent = (e) => { // TODO: Simplify the logic by isolating possibleAnswers from selectedQuestion
    const eventName = e.target.value;
    const selectedItemParams = `question_id=${selectedQuestion.id}&page_event_name=${eventName}`;
    const successCallback = (result) => {
      setSelectedQuestion(result);
      setSelectedEvent({name: eventName});
    };
    updateSelectedItems(selectedItemParams, successCallback);
    addSelectedItemToCurrentUrl('page_event_name', eventName);
  };

  const updateSelectedItems = (selectedItemParams, successCallback) => {
    const selectedFilters = window.location.search;
    $.ajax({
      url: `${props.itemUpdateUrl}${selectedFilters}&${selectedItemParams}`,
      method: 'GET',
      success: successCallback,
      error: () => {
        console.error('failed to update question and event!');
      },
    });
  };

  const addSelectedItemToCurrentUrl = (paramKey, itemValue) => { // Making the "Apply Filters" button send the selected item along with filter values
    const url = new URL(window.location);
    url.searchParams.set(paramKey, itemValue);
    window.history.pushState({}, '', url);
  };

  const orderedPossibleAnswers = () => { // TODO: DRY off with QuestionBox
    const possibleAnswers = [...selectedQuestion.possibleAnswers];
    return sortPossibleAnswers(possibleAnswers, possibleAnswerSortingOrder, possibleAnswerSortingDirection);
  };

  const possibleAnswerColor = (possibleAnswer) => newColors[possibleAnswer.id] || possibleAnswer.color;

  const updateColor = (possibleAnswerId, newColor, colorUpdateUrl) => {// TODO: DRY off with SurveyReport
    $.ajax({
      url: colorUpdateUrl,
      data: {
        color: newColor,
      },
      method: 'PATCH',
      success: (result) => {
        console.debug('successfully updated colour!');

        const approvedColors = {...newColors};
        approvedColors[possibleAnswerId] = newColor;

        setNewColors(approvedColors);
      },
      error: (result) => {
        console.error('failed to update colour!');
      },
    });
  };

  const viewFullScreen = () => {
    const chart = document.getElementById('page-event-chart-body');
    if (chart.requestFullscreen) {
      chart.requestFullscreen();
    } else if (chart.mozRequestFullScreen) {
      chart.mozRequestFullScreen();
    } else if (chart.webkitRequestFullscreen) {
      chart.webkitRequestFullscreen();
    } else if (chart.msRequestFullscreen) {
      chart.msRequestFullscreen();
    }
  };

  const downloadImage = () => {
    domtoimage.toPng(document.getElementById('page-event-chart-body')).then((dataUrl) => {
      const link = document.createElement('a');
      link.download = 'graph.png';
      link.href = dataUrl;
      link.click();
    });
  };

  const colorPickerData = orderedPossibleAnswers().map((possibleAnswer) => { // TODO: DRY off with QuestionBox
    return {
      id: possibleAnswer.id,
      name: possibleAnswer.content,
      color: newColors[possibleAnswer.id],
      colorUpdateUrl: possibleAnswer.colorUpdateUrl,
    };
  });

  const sortingOptions = [['position', 'Default'], ['alphabetical', 'Alphabetical'], ['event_answer_rate', 'Event Occurrence Rate']];

  const PageEventChartHeader = (props) => {
    return (
      <div className='page-event-chart-header'>
        <div className='select-container'>
          <label>QUESTION:</label>
          <select className='questions' onChange={updateSelectedQuestion}>
            {
              props.questions.map((question) =>{
                return <option key={question.id} value={question.id} selected={question.id === selectedQuestion.id}>{question.content}</option>;
              })
            }
          </select>
        </div>
        <div className='select-container'>
          <label>EVENT:</label>
          <select className='events' onChange={updateSelectedEvent}>
            {
              props.events.map((event) =>{
                return <option key={event.name} value={event.name} selected={event.name === selectedEvent.name}>{event.name}</option>;
              })
            }
          </select>
        </div>
        <BarChartSettings
          viewFullScreen={viewFullScreen}
          downloadImage={downloadImage}
          sortingOptions={sortingOptions}
          sortingOrder={possibleAnswerSortingOrder}
          sortingDirection={possibleAnswerSortingDirection}
          updateSorting={(newOrder, newDirection) => {
            setPossibleAnswerSortingOrder(newOrder);
            setPossibleAnswerSortingDirection(newDirection);
          }}
          legend={colorPickerData}
          updateColor={updateColor}
        />
      </div>
    );
  };

  const PageEventChart = (props) => {
    return (
      <div className='page-event-chart'>
        <PageEventChartHeader questions={props.questions} events={props.events}/>
        { /* NOTE: fullScreenEnabled is not used yet. See React.useEffect that toggles "full-screen" class */ }
        <div id='page-event-chart-body' className={fullScreenEnabled ? 'full-screen' : ''}>
          <div className='question-content'>{selectedQuestion.content}</div>
          <div className='possible-answer-containers'>
            <div className='average-answer-rate-line' style={{left: `${averageEventAnswerRate()}%`}}/>
            {
              orderedPossibleAnswers().map((possibleAnswer) => {
                return (
                  <div className='possible-answer-container' key={possibleAnswer.id}>
                    <div className='possible-answer-labels'>
                      <span className='possible-answer-content'>{possibleAnswer.content}</span>
                      <span className='possible-answer-answer-rate'>({possibleAnswer.answerRate}% of answers)</span>
                    </div>
                    <div className='result-bar-container'>
                      <div className='result-bar' style={{width: `${possibleAnswer.eventAnswerRate}%`, backgroundColor: possibleAnswerColor(possibleAnswer)}}/>
                      <div className='answer-rates'>
                        <span className='absolute-rate'>{possibleAnswer.eventAnswerRate}%</span>
                        <span className='relative-rate'>({relativeEventAnswerRateLabel(possibleAnswer.eventAnswerRate)})</span>
                      </div>
                    </div>
                  </div>
                );
              })
            }
            { /* "-1" is needed so the vertical average line meets "v" in "Avg" */ }
            <div className='average-answer-rate' style={{left: `${averageEventAnswerRate() -1}%`}}>
              <div>Avg</div>
              <div>{averageEventAnswerRate()}%</div>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const PageEventTable = () => {
    return (
      <div className='page-event-table'>
        <table>
          <thead>
            <tr>
              <th></th>
              {
                selectedQuestion.possibleAnswers.map((possibleAnswer) => {
                  return (
                    <th key={possibleAnswer.id}>
                      {possibleAnswer.content}
                    </th>
                  );
                })
              }
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>{selectedEvent.name} Occurred</td>
              {
                selectedQuestion.possibleAnswers.map((possibleAnswer) => {
                  return (
                    <td key={possibleAnswer.id}>
                      {possibleAnswer.eventAnswerCount}
                    </td>
                  );
                })
              }
              <td>{totalEventAnswerCount()}</td>
            </tr>
            <tr>
              <td>{selectedEvent.name} Didn't Occur</td>
              {
                selectedQuestion.possibleAnswers.map((possibleAnswer) => {
                  return (
                    <td key={possibleAnswer.id}>
                      {possibleAnswer.answerCount - possibleAnswer.eventAnswerCount}
                    </td>
                  );
                })
              }
              <td>{selectedQuestion.answerCount - totalEventAnswerCount()}</td>
            </tr>
            <tr className='total-row'>
              <td>Total</td>
              {
                selectedQuestion.possibleAnswers.map((possibleAnswer) => {
                  return (
                    <td key={possibleAnswer.id}>
                      {possibleAnswer.answerCount}
                    </td>
                  );
                })
              }
              <td>{selectedQuestion.answerCount}</td>
            </tr>
            <tr>
              <td>Event Occurrence Rate</td>
              {
                selectedQuestion.possibleAnswers.map((possibleAnswer) => {
                  return (
                    <td key={possibleAnswer.id}>
                      {possibleAnswer.eventAnswerRate}%
                    </td>
                  );
                })
              }
              <td>{averageEventAnswerRate()}%</td>
            </tr>
            <tr>
              <td>Change From Average</td>
              {
                selectedQuestion.possibleAnswers.map((possibleAnswer) => {
                  return (
                    <td key={possibleAnswer.id}>
                      {changeFromAverageRate(possibleAnswer.eventAnswerRate)}
                    </td>
                  );
                })
              }
              <td></td>
            </tr>
          </tbody>
        </table>
      </div>
    );
  };

  return (
    <>
      <PageEventChart questions={props.questions} events={props.events}/>
      <PageEventTable/>
    </>
  );
};

PageEvent.propTypes = {
  questions: PropTypes.array.isRequired,
  events: PropTypes.array.isRequired,
  selectedQuestion: PropTypes.object.isRequired, // TODO: Extract possibleAnswers from this
  selectedEvent: PropTypes.object.isRequired,
  itemUpdateUrl: PropTypes.string.isRequired,
};

export default PageEvent;
