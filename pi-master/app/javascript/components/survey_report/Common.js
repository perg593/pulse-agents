const activeStates = {
  active: 0,
  inactive: 1,
  default: 2,
};

/**
 * Basically a JS replica of Rails' number_to_percentage
 * @param {number} dividend
 * @param {number} divisor
 * @return {number}
 */
function numberToPercentage(dividend, divisor) {
  return (dividend * 100 / divisor).toFixed(2);
}

// TODO: Put somewhere better
// TODO: Add annotations
function sortPossibleAnswers(possibleAnswers, possibleAnswerSortingOrder, possibleAnswerSortingDirection) {
  switch (possibleAnswerSortingOrder) {
    case 'alphabetical':
      possibleAnswers.sort((a, b) => a.content.localeCompare(b.content));
      break;
    case 'answer_count':
      possibleAnswers.sort((a, b) => a.answerCount - b.answerCount);
      break;
    case 'event_answer_rate':
      possibleAnswers.sort((a, b) => a.eventAnswerRate - b.eventAnswerRate);
      break;
  }

  if (possibleAnswerSortingDirection === 'descending') {
    possibleAnswers.reverse();
  }

  return possibleAnswers;
}

export {activeStates, numberToPercentage, sortPossibleAnswers};
