// macbook-pro-16.local
// global-bobcat-com-preview.dibhids.net

var tabHost = document.location.hostname;
if (tabHost == "global-bobcat-com-preview.dibhids.net") {
	console.log(tabHost);

	(function() {
		var cssText =
			'#pulse_feedback_tab {'+
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
	  ;

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
		a.addEventListener("click", function() { pi('present', 3918) });


		document.body.appendChild(a);

		var body = document.getElementsByTagName('body')[0];

		body.appendChild(css);
		body.appendChild(a);
	})();

}
