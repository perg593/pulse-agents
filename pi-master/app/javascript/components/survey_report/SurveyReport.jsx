import React from 'react';
import PropTypes from 'prop-types';

import FreeTextQuestionBox from './FreeTextQuestionBox';
import QuestionBox from './QuestionBox';
import SummaryChartContainer from './summary_charts/SummaryChartContainer';
import CustomContentLinkClicks from "./CustomContentLinkClicks";

// TODO: Remove all the JQuery and break up into separate components and files
// TODO: Consolidate summary chart stat update. It's done here and in SummaryChartContainer

const SurveyReport = (props) => {
  const [data, setData] = React.useState(props.data);
  const [trendChartProps, setTrendChartProps] = React.useState(props.trendParams);

  const [
    selectedPossibleAnswerId, setSelectedPossibleAnswerId,
  ] = React.useState(null);

  const [SummaryChartData, setSummaryChartData] = React.useState(null);
  const [SummaryChartSummaries, setSummaryChartSummaries] = React.useState(null);

  const [newColors, setNewColors] = React.useState(() => {
    const updatedColors = {};

    props.data.forEach((datum) => {
      getPossibleAnswers(datum).forEach((possibleAnswer) => {
        updatedColors[possibleAnswer.id] = possibleAnswer.color;
      });
    });

    return updatedColors;
  });

  const searchParams = new URLSearchParams(window.location.search).toString();

  /**
   * Get a list of possible answers from the QuestionBox data
   * @param {object} an object containing the data for a QuestionBox component
   * @return {array} an array of possible answers
   **/
  function getPossibleAnswers(datum) {
    if (['free_text_question', 'custom_content_question'].includes(datum.question.type)) return [];
    return datum.possibleAnswers;
  }

  /**
   * Get IDs of questions pointing to this question
   * @param {number} questionId
   * @return {array} an array of question IDs
   **/
  function getPreviousQuestionIds(questionId) {
    return data.filter((datum) => {
      return getPossibleAnswers(datum).some((possibleAnswer) => {
        return possibleAnswer.nextQuestionId === questionId;
      });
    }).map((datum) => {
      return datum.question.id;
    });
  }

  /**
   * Get IDs of immediate descendent questions
   * @param {number} questionId
   * @return {array} an array of question IDs
   **/
  function getNextQuestionIds(questionId) {
    const ancestorQuestion = data.find((datum) => {
      return datum.question.id === questionId;
    });

    if (ancestorQuestion) {
      return getPossibleAnswers(ancestorQuestion).map((possibleAnswer) => {
        return possibleAnswer.nextQuestionId;
      }).flat();
    } else {
      return [];
    }
  }

  /**
   * Get IDs of all succeeding (descendent) questions
   * @param {number} questionId
   * @return {array} an array of question IDs
   **/
  function getDescendentQuestionIds(questionId) {
    if (questionId === null) {
      return null;
    }

    const nextQuestionIds = getNextQuestionIds(questionId);
    const result = [...nextQuestionIds];

    nextQuestionIds.forEach((nextQuestionId) => {
      if (nextQuestionId != '') {
        const descendentQuestionIds = getDescendentQuestionIds(nextQuestionId);

        if (descendentQuestionIds) {
          result.push(...descendentQuestionIds);
        }
      }
    });

    return result;
  }

  /**
   * Get IDs of all preceding (ancestor) questions
   * @param {number} questionId
   * @return {array} an array of question IDs
   **/
  function getAncestorQuestionIds(questionId) {
    const previousQuestionIds = getPreviousQuestionIds(questionId);
    const result = [...previousQuestionIds];

    previousQuestionIds.forEach((previousQuestionId) => {
      if (previousQuestionId != '') {
        result.push(...getAncestorQuestionIds(previousQuestionId));
      }
    });

    return result;
  }

  /**
   * Get IDs of questions to render
   * @return {array} - an array of numbers
   **/
  function questionIdsToShow() {
    if (selectedPossibleAnswerId === null) {
      // all question ids
      return data.map((datum) => datum.question.id);
    } else {
      let questionId = null;
      let nextQuestionId = null;

      data.forEach((datum) => {
        getPossibleAnswers(datum).forEach((possibleAnswer) => {
          if (possibleAnswer.id === selectedPossibleAnswerId) {
            questionId = datum.question.id;
            nextQuestionId = possibleAnswer.nextQuestionId;
          }
        });
      });

      if (nextQuestionId === null) {
        // all question ids
        return data.map((datum) => datum.question.id);
      } else {
        const goodQuestionIds = [questionId, nextQuestionId];

        goodQuestionIds.push(...getDescendentQuestionIds(nextQuestionId));
        goodQuestionIds.push(...getAncestorQuestionIds(questionId));

        return goodQuestionIds;
      }
    }
  }

  /**
   * Updates the summary charts
   * @param {object} sums - totals for headers
   * @param {object} dataPoints - points for charts
   **/
  function updateCharts(sums, dataPoints) {
    setSummaryChartSummaries({
      impressions: sums.impression_sum,
      submissions: sums.submission_sum,
      submissionRate: sums.submission_rate,
      viewedImpressions: sums.viewed_impression_sum,
    });

    const newData = {
      impressions: dataPoints.impression_sum,
      viewedImpressions: dataPoints.viewed_impression_sum,
      submissions: dataPoints.submission_sum,
      submissionRate: dataPoints.rate,
    };

    setSummaryChartData(newData);
  }

  /**
   * TODO: move working-overlay someplace better than the layout
   **/
  function addWorkingOverlay() {
    $('.container').addClass('overlay-container');
    $('.working-overlay').removeClass('hidden');
  }

  /**
   * TODO: move working-overlay someplace better than the layout
   **/
  function removeWorkingOverlay() {
    $('.container').removeClass('overlay-container');
    $('.working-overlay').addClass('hidden');
  }

  /**
   * Handles selection of a possible answer
   * @param {number} possibleAnswerId
   **/
  function handlePossibleAnswerSelection(possibleAnswerId) {
    const newPossibleAnswerId = selectedPossibleAnswerId === possibleAnswerId ? null : possibleAnswerId;

    setSelectedPossibleAnswerId(newPossibleAnswerId);
    updateStats(newPossibleAnswerId);
    updateTrendCharts(newPossibleAnswerId);
  }

  /**
   * Update stats for the trend charts
   * @param {number} possibleAnswerId - the selected possible answer ID
   * New data should only have submissions that included that possible answer ID
   */
  function updateTrendCharts(possibleAnswerId) {
    $.ajax({
      url: `${trendChartProps.updateUrl}?${searchParams}`,
      data: {
        possible_answer_id: possibleAnswerId,
      },
      success: (result) => {
        setTrendChartProps(result);
      },
    });
  }

  /**
   * TODO: Do as many of these calculations on the backend as possible
   * Update stats according to the selected bar
   * @param {number} possibleAnswerId - the ID of the possible
   *   answer that was selected
   **/
  function updateStats(possibleAnswerId) {
    let timer = undefined;

    $.ajax({
      url: `${props.filteringUrl}?${searchParams}`,
      data: {
        possible_answer_id: possibleAnswerId,
      },
      beforeSend: () => {
        timer && clearTimeout(timer);
        timer = setTimeout(() => {
          addWorkingOverlay();
          return;
        }, 500);
      },
      success: (res) => {
        clearTimeout(timer);
        removeWorkingOverlay();
        const report = res.report;
        const reportData = res.report_data;
        const result = res.result;

        // values in charts
        updateCharts(report, reportData);

        const newData = data.map((datum, index) => {
          return {
            ...datum,
            responseCount: result[index].responses,
            ungroupedResponseCount: result[index].ungrouped_responses,
          };
        });

        setData(newData.map((datum, index) => {
          const totalAnswerCount = datum.responseCount;

          let possibleAnswers = getPossibleAnswers(datum);
          possibleAnswers = possibleAnswers.map((possibleAnswer) => {

            // siblings of the clicked possible answer should not be affected,
            // neither should the clicked possible answer
            if (possibleAnswers.find((possibleAnswer) => possibleAnswer.id === possibleAnswerId)) {
              return possibleAnswer;
            }

            const answerCount = result[index].answers[possibleAnswer.id] || 0;
            const answerRate = Math.round(answerCount * 100.0 / totalAnswerCount) || 0;

            return {
              ...possibleAnswer,
              answerCount: answerCount,
              answerRate: answerRate,
            }
          });

          return {
            ...datum,
            possibleAnswers: possibleAnswers,
            updatePipes: true,
          };
        }));
      },
    });
  }

  const freeTextQuestionSelector = (datum) => {
    return `#free_text_question_${datum.question.id}`;
  };

  // TODO: can probably remove
  const freeTextQuestionAnchorSelector = (datum) => {
    return `#${freeTextQuestionAnchorId(datum)}`;
  };

  // TODO: can probably remove
  const freeTextQuestionAnchorId = (datum) => {
    return `free_text_question_anchor_${datum.question.id}`;
  };

  // toggle visiblity of free text questions
  // (because they can't hide themselves)
  // move them to their appropriate places in the question order
  // TODO: Remove
  React.useEffect(() => {
    data.filter((datum) => {
      return datum.question.type === 'free_text_question';
    }).forEach((datum) => {
      const freeTextQuestionElement = $(freeTextQuestionSelector(datum));

      if (questionIdsToShow().includes(datum.question.id)) {
        freeTextQuestionElement.show();
        freeTextQuestionElement.insertBefore(freeTextQuestionAnchorSelector(datum));
      } else {
        $(freeTextQuestionSelector(datum)).hide();
      }
    });
  }, [questionIdsToShow()]);

  const laneMapping = {};
  const lanesForRouting = (nextQuestionId) => {
    if (laneMapping[nextQuestionId] === undefined) {
      let nextLaneIndex = 0;

      if (Object.values(laneMapping).length) {
        nextLaneIndex = Math.max(...Object.values(laneMapping)) + 1;
      }

      laneMapping[nextQuestionId] = nextLaneIndex;
    }

    return laneMapping[nextQuestionId];
  };


  const trendData = (datum) => {
    return trendChartProps.questions[datum.question.id].seriesData;
  };

  const updateColor = (possibleAnswerId, newColor, colorUpdateUrl) => {
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

  return (
    <>
      <SummaryChartContainer
        numDaysActive={props.numDaysActive}
        asyncDataUrl={props.reportDataUrl}
        asyncSummariesUrl={props.reportSummariesUrl}
        newChartSummaries={SummaryChartSummaries}
        newChartData={SummaryChartData}
      />
      {
        data.filter((datum) => {
          return questionIdsToShow().includes(datum.question.id);
        }).map((datum) => {
          if (datum.question.type === 'custom_content_question') {
            return (
              <React.Fragment key={datum.question.id}>
                <CustomContentLinkClicks
                  questionId={datum.question.id}
                  questionContent={datum.question.content}
                  entireLinkClickCount={datum.entireLinkClickCount}
                  links={datum.links}
                />
              </React.Fragment>
            );
          } else if (datum.question.type === 'free_text_question') {
            return (
              <React.Fragment key={datum.question.id}>
                <FreeTextQuestionBox
                  numResponses={datum.responseCount}
                  question={datum.question}
                  responseSample={datum.responseSample}
                  title={datum.question.content}
                  tags={datum.tags}
                  includeAIAnalysis={props.includeAIAnalysis}
                  aiAnalysis={datum.aiAnalysis}
                />
                <div
                  key={datum.question.id}
                  id={freeTextQuestionAnchorId(datum)}
                />
              </React.Fragment>
            );
          } else {
            return (
              <React.Fragment key={datum.question.id}>
                <QuestionBox
                  updatePipes={datum.updatePipes}
                  possibleAnswers={datum.possibleAnswers}
                  question={datum.question}
                  lanesForRouting={lanesForRouting}
                  activePossibleAnswerId={selectedPossibleAnswerId}
                  handlePossibleAnswerSelection={handlePossibleAnswerSelection}
                  newColors={newColors}
                  numResponses={datum.responseCount}
                  numUngroupedResponses={datum.ungroupedResponseCount}
                  title={datum.question.content}
                  chartId={trendChartProps.questions[datum.question.id].chartId}
                  updateColor={updateColor}
                  seriesData={trendData(datum)}
                  dataLastUpdatedAt={trendChartProps.timestamp}
                  nextQuestionVisible={(questionId) => {
                    return questionIdsToShow().includes(questionId);
                  }}
                />
              </React.Fragment>
            );
          }
        })
      }
    </>
  );
};

SurveyReport.propTypes = {
  data: PropTypes.array.isRequired,
  numDaysActive: PropTypes.number.isRequired,
  reportDataUrl: PropTypes.string.isRequired,
  reportSummariesUrl: PropTypes.string.isRequired,
  filteringUrl: PropTypes.string.isRequired,
  includeAIAnalysis: PropTypes.bool.isRequired,
};

export default SurveyReport;
