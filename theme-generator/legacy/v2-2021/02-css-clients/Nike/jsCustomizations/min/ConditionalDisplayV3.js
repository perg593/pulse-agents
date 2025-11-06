
  var conditionalConfig = [
      {
        'id': 9849,
        'answers': {
          28252 : [
            {"id" : 9850} /*stars*/,
            {"id" : 9854} /*free text*/,
            {"id" : 9855} ,
            {"id" : 9859}
          ], //website
          28253 : [
            {"id" : 9850} /*stars*/,
            {
              "id" : 9852,
              'answers': {
                28271 : [
                  {"id" : 9858} /*primary app goal*/,
                  {"id" : 9859} /*how easy*/
                ]
              }
            }/*which app*/ ,
            {"id" : 9854} /*free text*/
          ], //apps
          28254 : [
            {"id" : 9850} /*stars*/,
            {"id" : 9854} /*free text*/,
            {"id" : 9856} /*store goal*/,
            {"id" : 9859} /*how easy*/
          ], //retail
          28255 : [
            {"id" : 9850} /*stars*/,
            {"id" : 9853} /*product type*/,
            {"id" : 9854} /*free text*/
          ], //products
          28256 : [
            {"id" : 9850} /*stars*/,
            {"id" : 9854} /*free text*//*support*/
          ], //customer service
          28257 : [
            {"id" : 9851} /*aspect of nike*/,
            {"id" : 9854} /*free text*/
          ], //nike
          28258 : [
            {"id" : 9854} /*free text*/
          ] //other
        }
      }
  ];
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

  Array.prototype.contains = function(obj) {
      var i = this.length;
      while (i--) {
          if (this[i] === obj) {
              return true;
          }
      }
      return false;
  };

  function Survey(config){
    this.questions = [];
    for (var i = 0; i < config.length; i++) {
      config[i].survey = this;
      this.questions[i] = new Question(config[i]);
      this.questions[i].hideQuestions(false);
    }
  }



  function Question(args){
    this.id = args.id;
    this.answers = args.answers;
    this.question = this.getPulseQuestion(this.id);
    this.qListValues = [];
    this.dependents = this.getDependents();
    this.dependentQuestions = this.getSubUnits();
    this.subUnits = this.getSubUnits();
    this.currentAnswer = null;
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
    var dependentQuestions = {};
    for (var i = 0; i < this.dependents.length; i++) {
      //get question el
      dependentQuestions[this.dependents[i]] = this.getPulseQuestion(this.dependents[i]);
      baseEl = PulseInsightsObject.survey.widgetContainer.querySelector('._pi_answers_container[data-question-id="'+ dependentQuestions[this.dependents[i]].id +'"]');

      // if(optional == "f"){
        //need to handle optional stuff
      // }
      dependentQuestions[this.dependents[i]].baseEl = baseEl;
      dependentQuestions[this.dependents[i]].questionEl = getPreviousSibling(baseEl, '_pi_question');
      if((dependentQuestions[this.dependents[i]].after_answers_count != "0" && dependentQuestions[this.dependents[i]].after_answers_count != "") && (dependentQuestions[this.dependents[i]].after_answers_items != null && dependentQuestions[this.dependents[i]].after_answers_items != '["", ""]') && dependentQuestions[this.dependents[i]].button_type === 1 && dependentQuestions[this.dependents[i]].question_type == "single_choice_question"){
        // get after answer el
        dependentQuestions[this.dependents[i]].afterAnswersEl = getNextSibling(baseEl, '_pi_scale_container_after');
      }
      else{
        dependentQuestions[this.dependents[i]].afterAnswersEl = null;
      }
      if(dependentQuestions[this.dependents[i]].before_answers_count != "0" && dependentQuestions[this.dependents[i]].before_answers_items != null && dependentQuestions[this.dependents[i]].button_type === 1 && dependentQuestions[this.dependents[i]].question_type == "single_choice_question"){
        // get before answer el
        dependentQuestions[this.dependents[i]].beforeAnswersEl = getPreviousSibling(baseEl, '_pi_scale_container_before');
      }
      else{
        dependentQuestions[this.dependents[i]].beforeAnswersEl = null;
      }
      if((dependentQuestions[this.dependents[i]].before_answers_count != "0" && dependentQuestions[this.dependents[i]].before_answers_count != "") && (dependentQuestions[this.dependents[i]].before_answers_items != null && dependentQuestions[this.dependents[i]].before_answers_items != '["", ""]') && dependentQuestions[this.dependents[i]].button_type === 1 && dependentQuestions[this.dependents[i]].question_type == "single_choice_question" ){
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
  };
  Question.prototype.attachEvents = function(){
    // single choice
    if(this.question.question_type == "single_choice_question"){
      // normal single choice

      if(this.question.button_type === 0 || this.question.button_type === 1){
        var els = PulseInsightsObject.survey.widget.querySelectorAll('._pi_answers_container[data-question-id="'+ this.question.id +'"] li a');
        var el;
        var self = this;
        for (var i = 0; i < els.length; i++) {
          // el = PulseInsightsObject.survey.widget.querySelector('[data-answer-id="' + this.answers[i].id + '"]');
          var elId = els[i].getAttribute('data-answer-id');

            el = els[i];
            el.addEventListener('click', function(){
              self.currentAnswer =  parseInt(this.getAttribute('data-answer-id'));
              if(typeof self.answers[self.currentAnswer] != 'undefined'){
                self.showQuestions();
              }
              else{
                self.hideQuestions(true);
              }

            });
          }

      }
      // select input
      else if(this.question.button_type === 2){
        var el = PulseInsightsObject.survey.widget.querySelector('._pi_answers_container[data-question-id="'+ this.question.id +'"] select._pi_select');

        el.addEventListener('change', function(e){
          if(typeof this.answers[el.value] != 'undefined'){
            this.currentAnswer =  parseInt(el.value);
            this.showQuestions();
          }
          else{
            this.hideQuestions(true);
          }
        }.bind(this));
      }
    }
    // multiple choice
    else if(this.question.question_type == "multiple_choices_question"){
      var parentEl = PulseInsightsObject.survey.widget.querySelector('._pi_answers_container[data-question-id="'+ this.question.id +'"]'),
          els = parentEl.querySelectorAll('li label'),
          keys;
      for (var i = 0; i < els.length; i++) {
        els[i].addEventListener('click', function(e){
          keys = Object.keys(this.answers);
          for (var j = 0; j < keys.length; j++) {
            if(parentEl.getAttribute('data-answer').indexOf(keys[j]) !== -1){
              this.currentAnswer =  parseInt(keys[j]);
              this.showQuestions();
            }
            else{
              this.hideQuestions(true);
            }
          }
        }).bind(this);
      }
    }
  };
  Question.prototype.getPulseQuestion = function(id){
    for (var i = 0; i < PulseInsightsObject.survey.questions.length; i++) {
      if(PulseInsightsObject.survey.questions[i].id === id){
        return PulseInsightsObject.survey.questions[i];
      }
    }
  };
  Question.prototype.getDependents = function(){
    var dependents = [],
        keys = Object.keys(this.answers);
    for (var i = 0; i < keys.length; i++) {
      for (var j = 0; j < this.answers[keys[i]].length; j++) {
        dependents = dependents.concat(this.answers[keys[i]][j].id).unique();
        var q = this.answers[keys[i]][j];
        if(typeof q.answers !== "undefined"){
          this.qListValues.push(new Question(q));
        }
      }
    }
    return dependents;
  };
  Question.prototype.showQuestions = function(){
    //check and see if its already shown
    if(this.currentAnswer !== null){
      var dependents = this.answers[this.currentAnswer];
      this.hideQuestions(true);
      if(typeof dependents !== 'undefined'){
        for (var i = 0; i < dependents.length; i++) {
          this.subUnits[dependents[i].id].questionEl.style.setProperty("display", "flex", "important");
          this.subUnits[dependents[i].id].baseEl.style.setProperty("display", "flex", "important");
          if(this.subUnits[dependents[i].id].optional == "f" && this.subUnits[dependents[i].id].question_type != "custom_content_question"){
            this.subUnits[dependents[i].id].baseEl.setAttribute("data-question-optional", "f");
          }
          if(this.subUnits[dependents[i].id].afterAnswersEl != null){
            this.subUnits[dependents[i].id].afterAnswersEl.style.setProperty("display", "flex", "important");
          }
          if(this.subUnits[dependents[i].id].beforeAnswersEl != null){
            this.subUnits[dependents[i].id].beforeAnswersEl.style.setProperty("display", "flex", "important");
          }
          if(this.subUnits[dependents[i].id].beforeQuestionEl != null){
            this.subUnits[dependents[i].id].beforeQuestionEl.style.setProperty("display", "block", "important");
          }
          if(this.subUnits[dependents[i].id].afterQuestionEl != null) {
            this.subUnits[dependents[i].id].afterQuestionEl.style.setProperty("display", "block", "important");
          }
          if(typeof PulseInsightsObject.survey.checkSubmissionCompleteness !== "undefined"){
            PulseInsightsObject.survey.checkSubmissionCompleteness(this.subUnits[dependents[i].id].baseEl);
          }
          if(typeof dependents[i].answers !== "undefined"){
            for (var j = 0; j < this.qListValues.length; j++) {
              if(this.qListValues[j].id == dependents[i].id){
                this.qListValues[j].showQuestions();
                break;
              }
            }
          }
        }

      }
    }
  };
  Question.prototype.hideQuestions = function(checkCompleteness){
    var keys = Object.keys(this.answers);
    for (var i = 0; i < keys.length; i++) {
      for (var j = 0; j < this.answers[keys[i]].length; j++) {
        this.subUnits[this.answers[keys[i]][j].id].questionEl.style.setProperty("display", "none", "important");
        this.subUnits[this.answers[keys[i]][j].id].baseEl.style.setProperty("display", "none", "important");
        this.subUnits[this.answers[keys[i]][j].id].baseEl.setAttribute("data-question-optional", "t");
        if(checkCompleteness && typeof PulseInsightsObject.survey.checkSubmissionCompleteness !== "undefined"){
          PulseInsightsObject.survey.checkSubmissionCompleteness(this.subUnits[this.answers[keys[i]][j].id].baseEl);
        }
        if(this.subUnits[this.answers[keys[i]][j].id].afterAnswersEl != null){
          this.subUnits[this.answers[keys[i]][j].id].afterAnswersEl.style.setProperty("display", "none", "important");
        }
        if(this.subUnits[this.answers[keys[i]][j].id].beforeAnswersEl != null){
          this.subUnits[this.answers[keys[i]][j].id].beforeAnswersEl.style.setProperty("display", "none", "important");
        }
        if(this.subUnits[this.answers[keys[i]][j].id].beforeQuestionEl != null){
          this.subUnits[this.answers[keys[i]][j].id].beforeQuestionEl.style.setProperty("display", "none", "important");
        }
        if(this.subUnits[this.answers[keys[i]][j].id].afterQuestionEl != null) {
          this.subUnits[this.answers[keys[i]][j].id].afterQuestionEl.style.setProperty("display", "none", "important");
        }

        //strip off ANSWERS
        if(this.subUnits[this.answers[keys[i]][j].id].question_type !== "free_text_question"){
          this.subUnits[this.answers[keys[i]][j].id].baseEl.removeAttribute("data-answer");
        }
        //single choice radio / standard
        if(this.subUnits[this.answers[keys[i]][j].id].button_type === 0 || this.subUnits[this.answers[keys[i]][j].id].button_type === 1){
          var answerEls = this.subUnits[this.answers[keys[i]][j].id].baseEl.querySelectorAll("li");
          for (var k = 0; k < answerEls.length; k++) {
            answerEls[k].classList.remove("selected");
          }
        }
        //dropdown
        else if(this.subUnits[this.answers[keys[i]][j].id].button_type === 2){
          this.subUnits[this.answers[keys[i]][j].id].baseEl.querySelectorAll("select option")[0].selected = 'selected';
        }
        // multiple choice
        else if(this.subUnits[this.answers[keys[i]][j].id].question_type == "multiple_choices_question"){
          var inputEls = this.subUnits[this.answers[keys[i]][j].id].baseEl.querySelectorAll("li input");
          for (var k = 0; k < inputEls.length; k++) {
            inputEls[k].checked = false;
          }
        }
        //free text
        // else if(this.subUnits[this.answers[keys[i]][j].id].question_type == "free_text_question"){
        //   var input = this.subUnits[this.answers[keys[i]][j].id].baseEl.querySelector("input, textarea");
        //   // input.value = '';
        //   //trigger event so keypress cb fires
        //   input.dispatchEvent(new KeyboardEvent('keypress',{'key':16}));
        // }
      }
    }
    if(this.qListValues.length > 0){
      for (var i = 0; i < this.qListValues.length; i++) {
        this.qListValues[i].hideQuestions(false);
      }
    }
    for (var i = 0; i < this.qListValues.length; i++) {
      this.qListValues[i].currentAnswer = null;
    }
    //check and see if its already hidden

    //determine if there are subelements and hide them
  };

  window.condSurvey = new Survey(conditionalConfig);

  var piInputs = document.querySelectorAll('._pi_free_text_question_field');
  for (var i = 0; i < piInputs.length; i++) {
    piInputs[i].addEventListener('keypress', function() {
      this.parentNode.parentNode.setAttribute('data-answer', this.value);
    });
    piInputs[i].addEventListener('keyup', function() {
      this.parentNode.parentNode.setAttribute('data-answer', this.value);
    });
  }
