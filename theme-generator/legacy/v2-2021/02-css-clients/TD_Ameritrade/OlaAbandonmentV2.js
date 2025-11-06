


var validateOLA = function(){
  if(typeof PulseInsightsObject != "undefined" && typeof PulseInsightsObject == "object"){
    if(typeof PulseInsightsObject.survey != "undefined" && typeof PulseInsightsObject.survey == "object"){
      //pulse is here, add validation
      var reqField = document.querySelector('[data-question-id="9062"]');
      PulseInsightsObject.survey.checkSubmissionCompleteness(reqField);
      PulseInsightsObject.survey.allSubmitButton.click();
      if(reqField.getAttribute("data-submit-error") == "true"){
        //failed validation -- don't redirect
        return false;
      }
      else{
        //passed validation -- redirect
        return true;
      }
    }
  }
  //pulse isn't here, default behavior -- redirect
  return true;
}


/*
psuedocode for TDA button event

exitButton.addEventListener("click", function(e){
  if(validateOLA()){
   do redirect
 }
});
 */
