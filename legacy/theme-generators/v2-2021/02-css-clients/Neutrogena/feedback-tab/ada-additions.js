var qEls = PulseInsightsObject.survey.widget.querySelectorAll("._pi_question"),
    contEls = PulseInsightsObject.survey.widget.querySelectorAll("._pi_answers_container");

PulseInsightsObject.survey.widget.querySelector("._pi_header.pi_header_after").setAttribute("id", "_pi_question_0_after_header");
PulseInsightsObject.survey.widget.querySelector("span._pi_accessbilityHidden").setAttribute("id", "_pi_accessbilityHidden");

var radioClickCB = function(el, elList){
  for (var i = 0; i < elList.length; i++) {
    elList[i].setAttribute("aria-checked", "false");
  }
  el.setAttribute("aria-checked", "true");
}

//add aria markup
for (var i = 0; i < qEls.length; i++) {
  qEls[i].setAttribute("id", "_pi_question_" + i);
}
for (var i = 0; i < contEls.length; i++) {
  //set labels
  if(contEls[i].getAttribute("data-question-type") === "single_choice_question"){
    if(i === 0){
      contEls[i].setAttribute("aria-labelledby", "_pi_question_" + i + " _pi_question_0_after_header");
    }
    else{
      contEls[i].setAttribute("aria-labelledby", "_pi_question_" + i);
    }
  }
  else if (contEls[i].getAttribute("data-question-type") === "free_text_question") {
    contEls[i].querySelector("input, textarea").setAttribute("aria-labelledby", "_pi_question_" + i);
  }
  //deal with required
  if(contEls[i].getAttribute("data-question-optional") === "f"){
    if(contEls[i].getAttribute("data-question-type") === "free_text_question"){
      contEls[i].querySelector("input, textarea").setAttribute("required");
    }
    else{
      contEls[i].setAttribute("aria-required", "true");
    }
  }
  //deal with radio role and group
  if(contEls[i].getAttribute("data-question-type") === "single_choice_question"){
    contEls[i].setAttribute("role", "radiogroup");
    var btnEls = contEls[i].querySelectorAll("li > a");
    for (var j = 0; j < btnEls.length; j++) {
      console.log(btnEls[j]);
      btnEls[j].setAttribute("role", "radio");
      btnEls[j].setAttribute("aria-checked", "false");
      btnEls[j].addEventListener("click", function(e){
        radioClickCB(this, btnEls);
      });
    }
  }
  else if(contEls[i].getAttribute("data-question-type") === "free_text_question") {
    contEls[i].setAttribute("role", "none");
  }
}
var surveyValid = true;
PulseInsightsObject.survey.allSubmitButton.addEventListener("click", function(e){
  for (var i = 0; i < contEls.length; i++) {
    if(PulseInsightsObject.survey.answerIsEmpty(contEls[i]) || PulseInsightsObject.survey.answerContainsBannedData(contEls[i])){
      contEls[i].setAttribute("aria-invalid", "true");
      surveyValid = false;
    }
  }
  if(!surveyValid){
    PulseInsightsObject.survey.widget.querySelector("._pi_all_questions_error").setAttribute("role", "alert");
  }
});
