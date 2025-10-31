# Pulse Insights Javascript Tag

<pre>
&lt;script&gt;

  window['pi']=function() {
  	window['pi'].q = window['pi'].q || [];
  	window['pi'].q.push(arguments);
  };

  surveysScript = document.createElement('script');
  surveysScript.async = 1;
  surveysScript.src = '//js.pulseinsights.com/surveys.js';

  firstScript = document.getElementsByTagName('script')[0];
  firstScript.parentNode.insertBefore(scriptInclude, surveysScript);

  pi('create', 'PI-12345678');
  pi('get', 'surveys');

&lt;/script&gt;
</pre>