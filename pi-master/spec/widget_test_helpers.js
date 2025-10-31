import 'intersection-observer';

import '../app/assets/javascripts/surveys/mixins.coffee';
import '../app/assets/javascripts/surveys/main.coffee';
import '../app/assets/javascripts/surveys/survey.coffee';
import '../app/assets/javascripts/surveys/single_page_app.coffee';

import '../app/assets/javascripts/surveys/callback.coffee';

import '../app/assets/javascripts/surveys/storage/local_storage.coffee';
import '../app/assets/javascripts/surveys/storage/cookies.coffee';
import '../app/assets/javascripts/surveys/storage/pageview_count.coffee';
import '../app/assets/javascripts/surveys/storage/visit_track.coffee';
import '../app/assets/javascripts/surveys/storage/visit_count.coffee';
import '../app/assets/javascripts/surveys/visitor_tracking.coffee';

import '../app/assets/javascripts/surveys/command_queue.coffee';

import '../app/assets/javascripts/surveys/render.coffee';
import '../app/assets/javascripts/surveys/free_text_question.coffee';
import '../app/assets/javascripts/surveys/multiple_choice_question.coffee';
import '../app/assets/javascripts/surveys/single_choice_question.coffee';
import '../app/assets/javascripts/surveys/slider_question.coffee';

import '../app/assets/javascripts/surveys/device_type.coffee';

import '../app/assets/javascripts/surveys.js';
import '../app/assets/javascripts/surveys/pulse_insights_library.js';

import '../app/assets/javascripts/surveys/get.coffee';
import '../app/assets/javascripts/surveys/jsonp.coffee';
import '../app/assets/javascripts/surveys/pdf_results.coffee';

import '../app/assets/javascripts/surveys/docked_widget_survey.coffee';

import '../app/assets/javascripts/surveys/intersection_observer.coffee';


/**
 * Calls a function every msDelay until it returns true
 * If it does not return true after maxWait, returns an error
 *
 * @param {function} condition - a function which must return true on success
 * @param {number} msDelay - the number of milliseconds to wait
 *   between calls to condition
 * @param {number} maxWait - the total number of milliseconds to
 *   wait before giving up
 **/
async function waitUntil(condition, msDelay = 200, maxWait = 2000) {
  let delayCounter = 0;

  return new Promise((resolve, reject) => {
    const intervalId = setInterval(() => {
      if (condition()) {
        clearInterval(intervalId);
        resolve();
      } else {
        delayCounter += msDelay;

        if (delayCounter >= maxWait) {
          clearInterval(intervalId);
          reject(new Error('Waited long enough!'));
        }
      }
    }, msDelay);
  });
}

/**
 * Waits until the survey is rendered
 **/
async function waitForSurvey() {
  // Survey checks rendering conditions every 100ms.
  await waitUntil(() => {
    return document.getElementById('_pi_surveyWidgetContainer') !== null;
  });
}

/**
 * Get question element by question DOM id
 * @param { number } questionId
 * @return { HTMLElement }
 **/
function getQuestionElementById(questionId) {
  return document.getElementById(`_pi_question_${questionId}`);
}

/**
 * Retrieves the answer container for a given question ID
 *
 * @param {string} questionId - The ID of the question
 * @return {HTMLElement|null} - The answer container if found, or null if not found
 */
function getAnswerContainer(questionId) {
  return document.querySelector(`._pi_answers_container[data-question-id='${questionId}']`);
}

export {getQuestionElementById, waitUntil, waitForSurvey, getAnswerContainer};
