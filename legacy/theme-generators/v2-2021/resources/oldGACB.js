console.log("Pulse Insights GA Event");
  if (typeof(ga) === 'function') {
  	var questionId = question.id;
  	var questionText = question.content;
  	var tracker = ga.getAll()[0].get('name');
  	if (answer.id == null) {
  		answerId = "Free text";
  	} else {
  		answerId = answer.id;
  	}
  	var answerText = answer.content;
  	ga(tracker + '.send', 'event', {
  		'eventCategory': 'survey response',
  		'eventAction': 'sID' + '_' + survey.attributes.id + ' | qID_' + questionId + ' | ' + questionText,
  		'eventLabel': answerId + ' | ' + answerText,
  	});
  }
