// ---------------- validations ----------------- //
function validateSSN (elementValue) {
  var  ssnPattern = /[0-9]{3}\-?[0-9]{2}\-?[0-9]{4}/;
  return ssnPattern.test(elementValue);
}

function validatePN (elementValue) {
  var pnPattern = /[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}/im;
  return pnPattern.test(elementValue);
}

function validateEmail (elementValue) {
  //var emailPattern = /(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))/;
  var emailPattern = /[\@]/;
  return emailPattern.test(elementValue);
}

function atLeastFive (elementValue) {
  var atLeastFivePattern = /(?=(\D*\d){5,}\D*)/;
  return atLeastFivePattern.test(elementValue);
}


function validateEntry() {
  var input = document.getElementsByClassName('_pi_free_text_question_field')[0].value;
  if (validateSSN(input)) {
    //pulseinsights('set_device_data', {rejectedSSN:'yes'});
    alert('Oops, looks like you are trying to submit personal information!');
  } else if (validatePN(input)) {
    //pulseinsights('set_device_data', {rejectedPhone:'yes'});
    alert('Oops, looks like you are trying to submit personal information!');
  } else if (validateEmail(input)) {
    //pulseinsights('set_device_data', {rejectedEmail:'yes'});
    alert('Oops, looks like you are trying to submit personal information!');
  } else if (atLeastFive(input)) {
    //pulseinsights('set_device_data', {rejectedOther:'yes'});
    alert('Oops, looks like you are trying to submit personal information!');
  } else {
    //pulseinsights('set_device_data', {validated:'yes'});
    window.PulseInsightsObject.survey.freeTextSubmitClicked();
  }
}

var interval = setInterval(function() {
  var submit_button = document.getElementsByClassName('_pi_free_text_question_submit_button')[0];
  if (typeof submit_button == 'undefined') return;
  clearInterval(interval);
  // the rest of the code
  submit_button.onclick = function() { validateEntry() };
}, 10);
