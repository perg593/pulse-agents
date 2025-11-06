// IMPRESSION ----------------------------------------------------------------------------------------

// var pi_searchTerm = document.querySelector("#root > div > div > div > div.css-1dbjc4n.r-13awgt0.r-1mlwlqe.r-1wgg2b2.r-13qz1uu > div > div:nth-child(1) > div > div > div.css-1dbjc4n.r-1awozwy.r-18u37iz.r-1wtj0ep > div.css-901oao.r-1jn44m2.r-1ui5ee8.r-vw2c0b.r-1qhn6m8").innerHTML.toString();
// pi_searchTerm = pi_searchTerm.substring(1, pi_searchTerm.length - 1);
function getCookie(cname) {
  var name = cname + "=";
  var decodedCookie = decodeURIComponent(document.cookie);
  var ca = decodedCookie.split(';');
  for(var i = 0; i <ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return c.substring(name.length, c.length);
    }
  }
  return "";
}

//var searchTerm;
//if(typeof utag_data.search_term !== "undefined"){
  //searchTerm = utag_data.search_term;
//}
//else{
//searchTerm = document.querySelector("#root > div > div > div > div.css-1dbjc4n.r-13awgt0.r-1mlwlqe.r-1wgg2b2.r-13qz1uu > div > div:nth-child(1) > div > div > div.css-1dbjc4n.r-1awozwy.r-18u37iz.r-1wtj0ep > div.css-901oao.r-1jn44m2.r-1ui5ee8.r-vw2c0b.r-1qhn6m8").innerHTML.toString();
//searchTerm = searchTerm.substring(1, searchTerm.length - 1);

//}


var sessionLink = getCookie("QuantumMetricSessionLink");
var sessionId = getCookie("QuantumMetricSessionID");
var userId = getCookie("QuantumMetricUserID");
var contextData  = {
  "quantumSessionId" : sessionId,
  "quantumSessionLink" : sessionLink,
  /*"searchTerm" : searchTerm,*/
  "urlOnCompletion" : window.location.href
};
var deviceData = {
  "QuantumUserId" : userId
};

pi("set_context_data", contextData);
pi("set_device_data", deviceData);


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
    alert('Oops! Please keep your responses to suggestions only! Thank you for helping us help you.');
  } else if (validatePN(input)) {
    //pulseinsights('set_device_data', {rejectedPhone:'yes'});
    alert('Oops! Please keep your responses to suggestions only! Thank you for helping us help you.');
  } else if (validateEmail(input)) {
    //pulseinsights('set_device_data', {rejectedEmail:'yes'});
    alert('Oops! Please keep your responses to suggestions only! Thank you for helping us help you.');
  } else if (atLeastFive(input)) {
    //pulseinsights('set_device_data', {rejectedOther:'yes'});
    alert('Oops! Please keep your responses to suggestions only! Thank you for helping us help you.');
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
  submit_button.onclick = function() { validateEntry(); };
}, 10);








// ANSWER ---------------------------------------------------------------------------------------------------

console.log("pi_searchTerm submitted:");
console.log(pi_searchTerm);
console.log("pi_sessionLink submitted:");
console.log(pi_sessionLink);
console.log("pi_contextData submitted:");
console.log(pi_contextData);
console.log("pi_deviceData submitted:");
console.log(pi_deviceData);
