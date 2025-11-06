//localization for select dropdowns

window.localizeSelects = function(string){
  var disabledEls = document.querySelectorAll('#_pi_surveyWidget select option[disabled]');
  for (var i = 0; i < disabledEls.length; i++) {
    disabledEls[i].innerHTML = string;
  }
}

//char count stuff for textinputs
window.localizeCharCounts = function(){
  var updateCharCount = function(max, current, displayEl){
    displayEl.innerHTML = current + '/' + max;
  };
  var textInputs = document.querySelectorAll("._pi_free_text_question_field"),
      charCountEl,
      maxChars,
      el;
  for (var i = 0; i < textInputs.length; i++) {
    el = textInputs[i];
    charCountEl = el.nextSibling;
    maxChars = charCountEl.getAttribute('data-max-length');
    el.setAttribute('maxLength', maxChars);
    charCountEl.style.setProperty('display', 'none');
    var newCharCountEl = document.createElement('div');
    newCharCountEl.setAttribute('class', '_pi_free_text_question_characters_count');
    el.parentNode.append(newCharCountEl);
    el.addEventListener('keyup', function(){updateCharCount(maxChars, el.value.length, newCharCountEl)});
    el.addEventListener('keypress', function(){updateCharCount(maxChars, el.value.length, newCharCountEl)});
  }
}

//conditional display Logic
Array.prototype.unique = function() {
  var a = this.concat();
  for(var i=0; i<a.length; ++i) {
      for(var j=i+1; j<a.length; ++j) {
          if(a[i] === a[j])
              a.splice(j--, 1);
      }
  }

  return a;
};

function Question(args){
  this.id = args.id;
  this.answers = args.answers;
  this.question = this.getPulseQuestion(this.id);
  this.dependents = this.getDependents();
  this.dependentQuestions = this.getSubUnits();
  this.subUnits = this.getSubUnits();
  this.attachEvents();
}
Question.prototype.getSubUnits = function(){
  var getPreviousSibling = function (elem, className) {

    // Get the next sibling element
    var sibling = elem.previousElementSibling;

    // If there's no className, return the first sibling
    if (!className) return sibling;

    // If the sibling matches our className, use it
    // If not, jump to the next sibling and continue the loop
    while (sibling) {
      if (sibling.classList.contains(className)) return sibling;
      sibling = sibling.previousElementSibling;
    }

  };
  var getNextSibling = function (elem, className) {

    // Get the next sibling element
    var sibling = elem.nextElementSibling;

    // If the sibling matches our className, use it
    // If not, jump to the next sibling and continue the loop
    while (sibling) {
      if (sibling.classList.contains(className)) return sibling;
      sibling = sibling.nextElementSibling;
    }

  };
  var dependentQuestions = {},
      baseEl;
  for (var i = 0; i < this.dependents.length; i++) {
    //get question el
    dependentQuestions[this.dependents[i]] = this.getPulseQuestion(this.dependents[i]);
    baseEl = PulseInsightsObject.survey.widgetContainer.querySelector('._pi_answers_container[data-question-id="'+ dependentQuestions[this.dependents[i]].id +'"]');

    // if(optional == "f"){
      //need to handle optional stuff
    // }
    dependentQuestions[this.dependents[i]].baseEl = baseEl;
    dependentQuestions[this.dependents[i]].questionEl = getPreviousSibling(baseEl, '_pi_question');
    if(dependentQuestions[this.dependents[i]].after_answers_count != "0" && dependentQuestions[this.dependents[i]].after_answers_items != null & dependentQuestions[this.dependents[i]].button_type === 1 && dependentQuestions[this.dependents[i]].question_type == "single_choice_question"){
      // get after answer el
      dependentQuestions[this.dependents[i]].afterAnswersEl = getNextSibling(baseEl, '_pi_scale_container_after');
    }
    else{
      dependentQuestions[this.dependents[i]].afterAnswersEl = null;
    }
    if(dependentQuestions[this.dependents[i]].before_answers_count != "0" && dependentQuestions[this.dependents[i]].before_answers_items != null & dependentQuestions[this.dependents[i]].button_type === 1 && dependentQuestions[this.dependents[i]].question_type == "single_choice_question"){
      // get before answer el
      dependentQuestions[this.dependents[i]].beforeAnswersEl = getPreviousSibling(baseEl, '_pi_scale_container_before');
    }
    else{
      dependentQuestions[this.dependents[i]].beforeAnswersEl = null;
    }
    if(dependentQuestions[this.dependents[i]].before_question_text != "" && dependentQuestions[this.dependents[i]].before_question_text !== null && dependentQuestions[this.dependents[i]].button_type === 1 && dependentQuestions[this.dependents[i]].question_type == "single_choice_question" ){
      // get before question el
      dependentQuestions[this.dependents[i]].beforeQuestionEl = getPreviousSibling(baseEl, 'pi_header_before');
    }
    else{
      dependentQuestions[this.dependents[i]].beforeQuestionEl = null;
    }
    if(dependentQuestions[this.dependents[i]].after_question_text != "" && dependentQuestions[this.dependents[i]].after_question_text !== null && dependentQuestions[this.dependents[i]].button_type === 1 && dependentQuestions[this.dependents[i]].question_type == "single_choice_question" ){
      // get after question el
      dependentQuestions[this.dependents[i]].afterQuestionEl = getPreviousSibling(baseEl, 'pi_header_after');
    }
    else{
      dependentQuestions[this.dependents[i]].afterQuestionEl = null;
    }
    // id: 8961
  }
  return dependentQuestions;
}
Question.prototype.attachEvents = function(){
  // single choice
  if(this.question.question_type == "single_choice_question"){
    // normal single choice

    if(this.question.button_type === 0 || this.question.button_type === 1){
      var els = document.querySelectorAll('._pi_answers_container[data-question-id="'+ this.question.id +'"] li a');
      for (var i = 0; i < els.length; i++) {
        // el = document.querySelector('[data-answer-id="' + this.answers[i].id + '"]');
        var elId = els[i].getAttribute('data-answer-id');
        if(typeof this.answers[elId] != 'undefined'){
          var dependents = this.answers[elId];
          els[i].addEventListener('click', function(){this.showQuestions(dependents)}.bind(this));
        }
        else{
          els[i].addEventListener('click', function(){this.hideQuestions()}.bind(this));
        }
      }
    }
    // select input
    else if(this.question.button_type === 2){
      var el = document.querySelector('._pi_answers_container[data-question-id="'+ this.question.id +'"] select._pi_select');

      el.addEventListener('change', function(){
        if(typeof this.answers[el.value] != 'undefined'){
          this.showQuestions(this.answers[el.value]);
        }
        else{
          this.hideQuestions();
        }
      }.bind(this));
    }
  }
  // multiple choice
  else if(this.question.question_type == "multiple_choices_question"){
    var parentEl = document.querySelector('._pi_answers_container[data-question-id="'+ this.question.id +'"]'),
        els = parentEl.querySelectorAll('li label'),
        keys;
    for (var i = 0; i < els.length; i++) {
      els[i].addEventListener('click', function(){
        keys = Object.keys(this.answers);
        for (var j = 0; j < keys.length; j++) {
          if(parentEl.getAttribute('data-answer').indexOf(keys[j]) !== -1){
            this.showQuestions(this.answers[keys[j]]);
          }
          else{
            this.hideQuestions();
          }
        }
      }).bind(this);
    }
  }
}
Question.prototype.getPulseQuestion = function(id){
  for (var i = 0; i < PulseInsightsObject.survey.questions.length; i++) {
    if(PulseInsightsObject.survey.questions[i].id === id){
      return PulseInsightsObject.survey.questions[i];
    }
  }
}
Question.prototype.getDependents = function(){
  var dependents = [],
      keys = Object.keys(this.answers);
  for (var i = 0; i < keys.length; i++) {
    dependents = dependents.concat(this.answers[keys[i]]).unique();
  }
  return dependents;
}
Question.prototype.showQuestions = function(dependents){
  //check and see if its already shown
  this.hideQuestions();
  for (var i = 0; i < dependents.length; i++) {
    this.subUnits[dependents[i]].questionEl.style.setProperty("display", "flex", "important");
    this.subUnits[dependents[i]].baseEl.style.setProperty("display", "flex", "important");

    if(this.subUnits[dependents[i]].afterAnswersEl != null){
      this.subUnits[dependents[i]].afterAnswersEl.style.setProperty("display", "flex", "important")
    }
    if(this.subUnits[dependents[i]].beforeAnswersEl != null){
      this.subUnits[dependents[i]].beforeAnswersEl.style.setProperty("display", "flex", "important");
    }
    if(this.subUnits[dependents[i]].beforeQuestionEl != null){
      this.subUnits[dependents[i]].beforeQuestionEl.style.setProperty("display", "block", "important");
    }
    if(this.subUnits[dependents[i]].afterQuestionEl != null) {
      this.subUnits[dependents[i]].afterQuestionEl.style.setProperty("display", "block", "important");
    }
  }

  //determine if there are subelements and show them
  // if(){
  //
  // }
  // else if(){
  //
  // }
}
Question.prototype.hideQuestions = function(){
  var keys = Object.keys(this.answers);
  for (var i = 0; i < keys.length; i++) {
    for (var j = 0; j < this.answers[keys[i]].length; j++) {
      this.subUnits[this.answers[keys[i]][j]].questionEl.style.setProperty("display", "none", "important");
      this.subUnits[this.answers[keys[i]][j]].baseEl.style.setProperty("display", "none", "important");

      if(this.subUnits[this.answers[keys[i]][j]].afterAnswersEl != null){
        this.subUnits[this.answers[keys[i]][j]].afterAnswersEl.style.setProperty("display", "none", "important");
      }
      if(this.subUnits[this.answers[keys[i]][j]].beforeAnswersEl != null){
        this.subUnits[this.answers[keys[i]][j]].beforeAnswersEl.style.setProperty("display", "none", "important");
      }
      if(this.subUnits[this.answers[keys[i]][j]].beforeQuestionEl != null){
        this.subUnits[this.answers[keys[i]][j]].beforeQuestionEl.style.setProperty("display", "none", "important");
      }
      if(this.subUnits[this.answers[keys[i]][j]].afterQuestionEl != null) {
        this.subUnits[this.answers[keys[i]][j]].afterQuestionEl.style.setProperty("display", "none", "important");
      }
    }
  }
  //check and see if its already hidden

  //determine if there are subelements and hide them




}
window.qList = [];
for (var i = 0; i < conditionalConfig.length; i++) {
  window.qList[i] = new Question(conditionalConfig[i]);
  window.qList[i].hideQuestions();
}
