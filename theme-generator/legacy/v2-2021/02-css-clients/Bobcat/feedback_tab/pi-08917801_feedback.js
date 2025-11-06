// FEEDBACK TAB
(function() {

/*
 * [determines which product we're on and returns the product object for later use]
 * @param  {string} tabHost     [current window.location.host]
 * @param  {[obj]} piDomainMap [js object containing a series of product objects]
 * @return {[obj]}             [the current product object]
 */
  var switcher = function(tabHost, piDomainMap){
    for (var j = 0; j < piDomainMap.length; j++) {
      for (var i = 0; i < piDomainMap[j].domains.length; i++) {
        if(piDomainMap[j].domains[i].comparitor(tabHost, piDomainMap[j].domains[i].domain)){
          return piDomainMap[j];
        }
      }
    }
  }
  var directComparitor = function(tabHost, selector){
    if(tabHost == selector){
      return true;
    }
    return false;
  }
  var wcComparitor = function(tabHost, wildcardSelector){
    if(tabHost.indexOf(wildcardSelector) !== -1){
      //substring exists
      return true;
    }
    return false;
  };

  piDomainMap = [
    {
      product: "marketing",
      domains: [
        {
          env: "dev",
          domain: "global-bobcat-com-preview.dibhids.net",
          comparitor: directComparitor
        },
        {
          env: "prod",
          domain: "www.bobcat.com",
          comparitor: directComparitor
        }
      ],
      cssText: '#pulse_feedback_tab {'+
	    	'position: fixed;'+
	    	'transform: rotate(-90deg);'+
	    	'right: -10px;'+
		    'transform-origin: 100% 100%;'+
		    'padding: 10px 25px 15px;'+
		    'color: white;'+
		    'text-transform: uppercase;'+
		    'text-decoration: none;'+
		    'font-size: 14px;'+
		    'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
		    'font-weight: normal;'+
		    'letter-spacing: normal;'+
		    'cursor: pointer;'+
		    'z-index: 600;'+
				'border: 1px solid #ffffff;'+
			'}'
	    +
	    '@media only screen and (min-width: 769px) {'+
			  '#pulse_feedback_tab {'+
			    'background-color: #ff3600;'+
					'top: 73%;'+
			  '}'+
	      '#pulse_feedback_tab:hover {'+
	        'background-color: #ff3600;'+
			    'right: 0px;'+
	    	'}'+
			'}'
	    +
	    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
	      '#pulse_feedback_tab {'+
	        'background-color: #ff3600;'+
	        'top: 70%;'+
	    	'}'+
			'}'
	    +
	    '@media only screen and (max-width: 425px) {'+
	    	'#pulse_feedback_tab {'+
	    		'background-color: #ff3600;'+
	    		'padding: 8px 20px 15px;'+
	    		'top: 68%;'+
	    	'}'+
			'}'
    },
    {
      product: "owners",
      domains: [
        {
          env: "dev",
          domain: "my-bobcat.dev.dice-tools.com",
          comparitor: wcComparitor
        },
        {
          env: "qa",
          domain: "my-bobcat.qa.dice-tools.com",
          comparitor: directComparitor
        },
        {
          env: "old-prod",
          domain: "new.my.bobcat.com",
          comparitor: directComparitor
        },
        {
          env: "new-prod",
          domain: "my.bobcat.com",
          comparitor: directComparitor
        }
        // {
        //   env: "new-dev",
        //   domain: "new.my.bobcat.com",
        //   comparitor: directComparitor
        // }
      ],
      cssText: '#pulse_feedback_tab {'+
	    	'position: fixed;'+
	    	'transform: rotate(-90deg);'+
	    	'right: -10px;'+
		    'transform-origin: 100% 100%;'+
		    'padding: 10px 25px 15px;'+
		    'color: white;'+
		    'text-transform: uppercase;'+
		    'text-decoration: none;'+
		    'font-size: 14px;'+
		    'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
		    'font-weight: normal;'+
		    'letter-spacing: normal;'+
		    'cursor: pointer;'+
		    'z-index: 600;'+
				'box-shadow: 0px 0px 2px gray;'+
			'}'
	    +
	    '@media only screen and (min-width: 769px) {'+
			  '#pulse_feedback_tab {'+
			    'background-color: #ff3600;'+
					'top: 50%;'+
			  '}'+
	      '#pulse_feedback_tab:hover {'+
	        'background-color: #ff3600;'+
			    'right: 0px;'+
	    	'}'+
			'}'
	    +
	    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
	      '#pulse_feedback_tab {'+
	        'background-color: #ff3600;'+
	        'top: 50%;'+
	    	'}'+
			'}'
	    +
	    '@media only screen and (max-width: 425px) {'+
	    	'#pulse_feedback_tab {'+
	    		'background-color: #ff3600;'+
	    		'padding: 8px 20px 15px;'+
	    		'top: 68%;'+
	    	'}'+
			'}'
    },
    {
      product: "dealers",
      domains: [
        {
          env: "dev",
          domain: "bobcatdealernet.dev.dice-tools.com",
          comparitor: wcComparitor
        },
        {
          env: "qa",
          domain: "bobcatdealernet.qa.dice-tools.com",
          comparitor: directComparitor
        },
        {
          env: "prod",
          domain: "dealer.bobcat.com",
          comparitor: directComparitor
        }
      ],
      cssText: '#pulse_feedback_tab {'+
	    	'position: fixed;'+
	    	'transform: rotate(-90deg);'+
	    	'right: -10px;'+
		    'transform-origin: 100% 100%;'+
		    'padding: 10px 25px 15px;'+
		    'color: white;'+
		    'text-transform: uppercase;'+
		    'text-decoration: none;'+
		    'font-size: 14px;'+
		    'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
		    'font-weight: normal;'+
		    'letter-spacing: normal;'+
		    'cursor: pointer;'+
		    'z-index: 600;'+
				'box-shadow: 0px 0px 2px gray;'+
			'}'
	    +
	    '@media only screen and (min-width: 769px) {'+
			  '#pulse_feedback_tab {'+
			    'background-color: #ff3600;'+
					'top: auto%;'+
          'bottom: calc(5% + 300px)' +
			  '}'+
	      '#pulse_feedback_tab:hover {'+
	        'background-color: #ff3600;'+
			    'right: 0px;'+
	    	'}'+
			'}'
	    +
	    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
	      '#pulse_feedback_tab {'+
	        'background-color: #ff3600;'+
	        'top: auto;'+
          'bottom: 50%;' +
	    	'}'+
			'}'
	    +
	    '@media only screen and (max-width: 425px) {'+
	    	'#pulse_feedback_tab {'+
	    		'background-color: #ff3600;'+
	    		'padding: 8px 20px 15px;'+
	    		'top: auto;'+
          'bottom: 50%' +
	    	'}'+
			'}'
    },
  ];

var showChildren = function(){
  setTimeout(function(){
    var widgetContainer = window.PulseInsightsObject.survey.widgetContainer,
        widget = window.PulseInsightsObject.survey.widgetContainer.querySelector("#_pi_surveyWidget"),
        contentContainer = window.PulseInsightsObject.survey.widgetContainer.querySelector("._pi_widgetContentContainer"),
        question = window.PulseInsightsObject.survey.widgetContainer.querySelector("._pi_question");
        if(widgetContainer != null){
          widgetContainer.style.removeProperty("display")
        }
        if(widget != null){
          widget.style.setProperty("max-height", "none")
        }
        if(contentContainer != null){
          contentContainer.style.removeProperty("display")
        }
        if(question != null){
          question.style.removeProperty("display")
        }
  }, 500);
}
/*
 * [attaches click events to menu triggers so we can present]
 * @return {void} nuthin
 */
  var buildClickEvents = function(){
    window.piMobileclickEventListener = function(e){
      var mobileMenuTrigger = document.querySelector(".btn.btn-menu.mobile-trigger[data-target='#mobile-menu']");
      if(mobileMenuTrigger !== null){
        if(mobileMenuTrigger.classList.contains("collapsed")){
          display();
        }
      }
    };
    window.piClickEventListener = function(e){
      display();
    };

    var delayInMilliseconds = 1000; //1 sec

    if(typeof window.piInit  == "undefined"){
      window.survey_answered = false;
    }

    function display() {
      if(typeof window.PulseInsightsObject.survey != "undefined"){
        pi_nav = window.PulseInsightsObject.survey;
      }
      //we're already on the right survey, or its already been answered, window.survey set in the complete cb field
      if(typeof pi_nav != "undefined"){
        if (pi_nav.attributes.id === 3961 || pi_nav.attributes.id === 4002 || window.survey_answered === true) {
          showChildren();
          return;
        }
      }
      else{
        if(window.innerWidth <= 990){
          pi("present", 4002);
          showChildren();
          // setTimeout(function(){pi("present", 4002);}, 700);

        }
        else{
          pi("present", 3961);
          showChildren();
        }
      }
    }

    //attach event listeners on a timer
    setTimeout(function () {
      window.piInit = false;
      var desktopMenuTrigger = document.querySelector("#main-nav > li.level-1:nth-child(8) a");
      if(desktopMenuTrigger !== null){
        desktopMenuTrigger.addEventListener("click", window.piClickEventListener, true);
      }
      var menuTrigger = document.querySelector(".btn.btn-menu.mobile-trigger[data-target='#mobile-menu']");
      if(menuTrigger !== null){
        menuTrigger.addEventListener("click", window.piMobileclickEventListener, true);
      }
    });
  };



/*
  build anchor tag and attach present methods
  @param  string cssText string containing valid css to style the feedback button
  @return void         nuthin
*/
  var buildEl = function(cssText){
    var css = document.createElement('style');
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
    // a.addEventListener("click", function() { pi('present', 'pi-feedback-tab') });
    a.addEventListener("click", function() { pi('present', eventName) });


    document.body.appendChild(a);

    var body = document.getElementsByTagName('body')[0];

    body.appendChild(css);
    body.appendChild(a);
  };

/*
 initialize variables and set up switch statement
 */
var tabHost = document.location.hostname,
    eventName,
    selProd = switcher(tabHost, piDomainMap);

if(selProd){
  switch (selProd.product) {
    case "marketing":
      buildClickEvents();
      eventName = 'marketing-site-feedback';
      buildEl(selProd.cssText);
      break;
    case "owners":
      eventName = 'my-bobcat-feedback';
      buildEl(selProd.cssText);
      break;
    case "dealers":
      eventName = 'dealer-feedback';
      buildEl(selProd.cssText);
      break;
    default:

  }
}

})();
