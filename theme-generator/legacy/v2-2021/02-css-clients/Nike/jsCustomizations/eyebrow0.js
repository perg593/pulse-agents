//make sure we exist
if(typeof PulseInsightsObject != "undefined"){
  if(typeof PulseInsightsObject.survey != "undefined"){
    // list of dropdowns and survye reference defs
    var cb = function(i){
      return function(){
        console.log('changed_' + i);
        if(qL[i].eyebrowShown === false){
          qL[i].eyebrow.style.setProperty("display", "block");
          qL[i].eyebrowShown = true;
        }
      }
      // console.log(qObj);

    };
    window.qL = [],
        survey = PulseInsightsObject.survey;
    // find dropdown questions
    for (var i = 0; i < survey.questions.length; i++) {
      //check button_type and question type to make sure we've got a dropdown
      if(survey.questions[i].button_type == 2 && survey.questions[i].question_type == "single_choice_question"){
        qL.push(survey.questions[i]);
      }
    }
    if(qL.length > 0){
      var eyebrow;
      for (var i = 0; i < qL.length; i++) {
        //get question container
        qL[i].el = PulseInsightsObject.survey.widget.querySelector('[data-question-id="' + qL[i].id + '"]');
        qL[i].el.classList.add("isDropdown");
        qL[i].eyebrowShown = false;
        qL[i].eyebrow = document.createElement('div');
        qL[i].eyebrow.setAttribute('class', 'eyebrow');
        qL[i].eyebrow.setAttribute('id', qL[i].id + '_eyebrow');
        qL[i].eyebrow.textContent = qL[i].single_choice_default_label;
        qL[i].el.append(qL[i].eyebrow);
        qL[i].el.querySelector("select._pi_select").addEventListener("change", cb(i));
      }
    }
    console.log(qL);
  }
}
