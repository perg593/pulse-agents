/* CHECKBOXES FOR QUESTION TYPE - JAVASCRIPT HIDE/SHOW */
function hideshow(which) {
	if (which.style.display == "none") {
		which.style.display = "block";
	} else {
		which.style.display = "none";
	}
}

function hidecard(cardtype) {
	var cardTypes = document.querySelectorAll(cardtype);
	for (var i = 0; i < cardTypes.length; i++) {
		if (cardtype.style.display == "none") {
			cardtype.style.display = "block";
		} else {
			cardtype.style.display = "none";
		}
	}
}

 
/* RADIO BUTTONS FOR SURVEY TYPE - JAVASCRIPT HIDE/SHOW */
function changeSurvey(x) {
	var surveyWidgets = document.querySelectorAll("#_pi_surveyWidget");
	for (var i = 0; i < surveyWidgets.length; i++) {
		surveyWidgets[i].setAttribute("survey-widget-type", x);
	}
}


// ------ ADD CLOSE PI WIDGET FUNCTION TO ALL SURVEYS
document.addEventListener(
	"mousemove",function() {
		var add_pi_closeDiv = document.querySelectorAll("._pi_closeButton");
		var add_pi_closeCustomDiv = document.querySelectorAll("._pi_closeCustomButton");

		for (var i = 0; i < add_pi_closeDiv.length; i++) {
			add_pi_closeDiv[i].setAttribute("onclick", "closePiWidget(" + i + ")");
		}

		for (var i = 0; i < add_pi_closeCustomDiv.length; i++) {
			add_pi_closeCustomDiv[i].setAttribute("onclick", "closePiCustomWidget(" + i + ")");
		}

	},false
);


// ------ CLOSE FUNCTION FOR ALL WIDGETS (DISPLAY = NONE)
function closePiWidget(x) {
	var pi_closeDiv = document.querySelectorAll("#_pi_surveyWidget");
	for (var i = 0; i < pi_closeDiv.length; i++) {
		pi_closeDiv[x].style.display = "none";
	}
}

function closePiCustomWidget(x) {
	var pi_closeCustomDiv = document.querySelectorAll("#_pi_surveyWidgetCustom");
	for (var i = 0; i < pi_closeCustomDiv.length; i++) {
		pi_closeCustomDiv[x].style.display = "none";
	}	
}


/* WINDOW DIMENSIONS */
window.onresize = displayWindowSize;
window.onload = displayWindowSize;

function displayWindowSize() {
	myWidth = window.innerWidth;
	myHeight = window.innerHeight;
	// your size calculation code here
	// document.getElementById("dimensions").innerHTML = myWidth + "x" + myHeight;
	document.getElementById("dimensions-desktop").innerHTML  = "<b>Current: </b>" + myWidth + "px";
	document.getElementById("dimensions-tablet").innerHTML   = "<b>Current: </b>" + myWidth + "px";
	document.getElementById("dimensions-phone414").innerHTML = "<b>Current: </b>" + myWidth + "px";
	document.getElementById("dimensions-phone375").innerHTML = "<b>Current: </b>" + myWidth + "px";
	document.getElementById("dimensions-phone320").innerHTML = "<b>Current: </b>" + myWidth + "px";
}
