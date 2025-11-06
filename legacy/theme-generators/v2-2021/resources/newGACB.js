console.log("Pulse Insights GA Event");
  if (typeof(ga) === 'function') {
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
