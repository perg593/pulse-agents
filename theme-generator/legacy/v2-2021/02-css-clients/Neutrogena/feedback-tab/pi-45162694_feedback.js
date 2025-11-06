(function() {
	var cssText = '#pulse_feedback_tab{'+
	'background-color: #8dabbd;'+
	'position: fixed;'+
	'transform: rotate(-90deg);'+
	'right: -10px;'+
	'transform-origin: 100% 100%;'+
	'padding: 10.5px 25px 15.5px;'+
	'color: white;'+
	'text-transform: uppercase;'+
	'text-decoration: none;'+
	'font-size: 14px;'+
	'font-family: Helvetica;'+
	'font-weight: bold;'+
	'letter-spacing: .075px;'+
	'top: 67%;'+
	'cursor: pointer;'+
	'z-index: 120;}'+
	'@media only screen and (min-width: 769px){'+
	'#pulse_feedback_tab:hover{'+
	'background-color: #89a5b6;'+
	'right: 0px;}}'+
	'@media only screen and (max-width: 425px){'+
	'#pulse_feedback_tab { display: none; }}';

	css = document.createElement('style');
	css.type = "text/css";
	css.className = "pulse_feedback_css";

	if (css.styleSheet) {
		css.styleSheet.cssText = cssText;
	} else {
	  css.appendChild(document.createTextNode(cssText));
	}

	var a = document.createElement('a');
	var linkText = document.createTextNode("FEEDBACK");
	a.appendChild(linkText);
	a.id = "pulse_feedback_tab";
	if(window.location.hostname == "www.neutrogena.com"){
		a.addEventListener("click", function() { pi('present', 'pi-feedback-tab')
			setTimeout(function(){
			var c = 0;
			var checkExist = setInterval(function() {
				if (document.querySelectorAll("._pi_widgetContentContainer").length > 0) {
				 	document.querySelector("#_pi_surveyWidget").setAttribute("tabindex", 0);
				 	document.querySelector("#_pi_surveyWidget").setAttribute("role", "form");
				 	document.querySelector("#_pi_surveyWidget").setAttribute("aria-labelledby", "_pi_accessbilityHidden");
					document.querySelector("#_pi_surveyWidget").focus();
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
					//fix char counts
					PulseInsightsObject.survey.updateCharactersCountLabel = function(input) {
					   var answerContainer, answerLength, charactersCountLabelTextNode, maxLength, ref, remainingCharacters;
					   var charCountEl = event.target.nextElementSibling.querySelector('._pi_free_text_question_characters_count');
					   if (answerLength = input.value.length,
					      0 !== (maxLength = charCountEl.getAttribute("data-max-length")))
					      return charactersCountLabelTextNode = document.createTextNode(answerLength + "/" + maxLength),
					      charCountEl.innerHTML = "",
					      charCountEl.appendChild(charactersCountLabelTextNode),
					      event && event.target && event.target.parentNode && (answerContainer = event.target.parentNode.parentNode),
					      answerContainer && answerContainer.setAttribute("data-answer", event.target.value),
					      (remainingCharacters = maxLength - answerLength) > 0 ? (charCountEl.setAttribute("class", "_pi_free_text_question_characters_count " + (remainingCharacters < 20 ? "danger" : void 0)),
					      this.submitButton.removeAttribute("disabled")) : 0 === remainingCharacters ? event && 46 !== (ref = event.keyCode) && 8 !== ref && event.preventDefault() : (this.submitButton.setAttribute("disabled", "disabled"),
					      answerContainer && answerContainer.setAttribute("data-answer", "")),
					      "t" !== this.attributes.display_all_questions ? this.toggleSubmitButton() : answerContainer ? this.checkSubmissionCompleteness(answerContainer) : void 0
					   }

					clearInterval(checkExist);
				}
				if(c > 10){
					clearInterval(checkExist);
					console.log("took too long to find widget, aborting");
				}
				c++;
			}, 100);
		},
		400);
		});
	}
	else{
		a.addEventListener("click", function() { pi('present', 'pi-staging-feedback-tab') });
	}

	document.body.appendChild(a);

	body = document.getElementsByTagName('body')[0];

	body.appendChild(css);
	body.appendChild(a);
})();
