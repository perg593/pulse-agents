import consumer from "./consumer"

export default {
  subscribe(surveyId, callbacks) {
    return consumer.subscriptions.create(
      { channel: "SurveyRecommendationsChannel", survey_id: surveyId },
      {
        connected() {
          if (callbacks.connected) callbacks.connected();
        },

        disconnected() {
          if (callbacks.disconnected) callbacks.disconnected();
        },

        received(data) {
          if (callbacks.received) callbacks.received(data);
        }
      }
    );
  }
}
