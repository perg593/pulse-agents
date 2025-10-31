if(PulseInsightsObject.survey.attributes.survey_type === 3){
  var isiContainer;
  var isiContainer = document.querySelector(".isi-container");
  var isiStyleObj = window.getComputedStyle(isiContainer);
  var piUpdatePosition = function(){
      var isiHeight = parseInt(isiStyleObj.height) + parseInt(isiStyleObj.marginBottom);
      if(!isiContainer.classList.contains("open")){
        PulseInsightsObject.survey.widget.style.setProperty("bottom", isiHeight + "px");
      }
      else{
        PulseInsightsObject.survey.widget.style.setProperty("bottom", 0);
      }
  }
  var piResizeListener = window.addEventListener("resize", piUpdatePosition);
  var piScrollListener = document.addEventListener("scroll", piUpdatePosition);

}

if(PulseInsightsObject.survey.attributes.survey_type === 1){
//  var isiStyleObj = window.getComputedStyle(isiContainer);
var c = 0;
 var checkExist = setInterval(function() {
   if (document.querySelectorAll("._pi_widgetContentContainer").length > 0) {
     window.piUpdatePosition = function(){
         var isiContainer = document.querySelector(".isi-container");
         if(!isiContainer.parentElement.classList.contains("open")){
           PulseInsightsObject.survey.widget.style.setProperty("bottom", "100%");
           PulseInsightsObject.survey.widget.style.setProperty("position", "absolute");
         }
         else{
           PulseInsightsObject.survey.widget.style.setProperty("bottom", 0);
           PulseInsightsObject.survey.widget.style.setProperty("position", "fixed");
         }
     }
     var piResizeListener = window.addEventListener("resize", piUpdatePosition);
     var piScrollListener = document.addEventListener("scroll", piUpdatePosition);
     piUpdatePosition();
     clearInterval(checkExist);
   }
   c++;
   if(c > 15){
     clearInterval(checkExist);
   }
 }, 100);
}

//remove this when we go away
window.removeEventListener("resize", window.piUpdatePosition);
document.removeEventListener("scroll", window.piUpdatePosition);
