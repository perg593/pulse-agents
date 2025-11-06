if(typeof(gtag) === "function"){
     //'ga 4 available, run v4 callback'
     var survey = PulseInsightsObject.survey;
     if (answer.id == null) {
   		answerId = "Free text";
        answerText = "";
   	}
     else {
   		answerId = answer.id;
        answerText = answer.content;
   	}
     gtag("event", "surveyAnswered", {
      survey_id: survey.attributes.id,
      acc_identifier: PulseInsightsObject.identifier,
      question_id: question.id,
      question_text: question.content,
      answer_id: answerId,
      answer_text: answerText,
    });
}
else if (typeof(ga) === 'function') {
   //'using old ga scheme proceed with old callback'
   var questionId = question.id,
       questionText = question.content,
       tracker = ga.getAll()[0].get('name'),
        answerText;
   if (answer.id == null) {
       answerId = "Free text";
      answerText = "";
   }
    else {
       answerId = answer.id;
      answerText = ' | ' + answer.content;
   }
   ga(tracker + '.send', 'event', {
       'eventCategory': 'survey response',
       'eventAction': 'sID' + '_' + survey.attributes.id + ' | qID_' + questionId + ' | ' + questionText,
       'eventLabel': answerId + answerText,
   });
}
else{
   //'analytics prop unavailable, ga unavailable'
}
