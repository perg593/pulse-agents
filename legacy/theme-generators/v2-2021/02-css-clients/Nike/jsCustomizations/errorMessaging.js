var localizeErrorMessage = function(string){
  setTimeout(function(){
    var submitEl = PulseInsightsObject.survey.widgetContainer.querySelector('input._pi_all_questions_submit_button[type="submit"]'),
        errorEl = PulseInsightsObject.survey.widgetContainer.querySelector('._pi_all_questions_error');

    submitEl.addEventListener('click', function(){
      setTimeout(function(){
        if(errorEl.innerHTML == "Please fill all answers"){
          errorEl.innerHTML = string;
          errorEl.style.setProperty("display", "block", "important");
        }
      }, 200);
    });
  },200);
}
