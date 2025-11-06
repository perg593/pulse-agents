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
			var i = 0;
			var checkExist = setInterval(function() {
				if (document.querySelectorAll("#_pi_surveyWidget").length > 0) {
				 	document.querySelector("#_pi_surveyWidget").setAttribute("tabindex", 0);
				 	document.querySelector("#_pi_surveyWidget").setAttribute("role", "form");
				 	document.querySelector("#_pi_surveyWidget").setAttribute("aria-labelledby", "_pi_accessbilityHidden");
					document.querySelector("#_pi_surveyWidget").focus();
					clearInterval(checkExist);
				}
				if(i > 10){
					clearInterval(checkExist);
					console.log("took too long to find widget, aborting");
				}
				i++;
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
