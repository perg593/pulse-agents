var selectorMap = {
  "/" : {
    "selectors" : ["#main > div.category-grid"],
    "mode" : "1"
  },
  "/the-bar/spice-it-up-7-turmeric-benefits-for-skin.html" : {
    "selectors" : ["#primary > div > div.ch-ap-content-wrapper > div.ch-ap-left-wrapper > div.module-d.get-the-look"],
    "mode" : "1"
  },
  "/products/skincare/neutrogena-hydro-boost-water-gel-with-hyaluronic-acid-for-dry-skin/6811047.html" : {
    "selectors" : ["#pdpMain > div.product-info.clearfix"],
    "mode" : "1"
  },
  "/products/skincare/wrinkle-fighting-duo-set/1700095.html" : {
    "selectors" : ["#pdpMain > div.product-col-2.product-detail.product-set"],
    "mode" : "1"
  },
  "/skin/skin-cleansers" : {
    "selectors" : ["#primary > div.search-results-guts > div.module-contenthub-related"],
    "mode" : "1"
  },
  "/skin/skin-moisturizers" : {
    "selectors" : ["#primary > div.search-results-guts > div.module-contenthub-related"],
    "mode" : "1"
  },
  "/skin/hydro-boost.html" : {
    "selectors" : ["#primary > div:nth-child(3) > div:nth-child(2)"],
    "mode" : "1"
  },
  "/skin/rapidwrinklerepair.html" : {
    "selectors" : ["#primary > div:nth-child(1) > div:nth-child(5)"],
    "mode" : "1"
  },
  "/skin/skin-agingskin" : {
    "selectors" : ["#pll-anti-aging-ingredients-highlights"],
    "mode" : "1"
  },
  "/skin" : {
    "selectors" : ["#main > div:nth-child(5)"],
    "mode" : "0"
  },
  "/skin/bright-boost.html" : {
    "selectors" : ["#primary > div:nth-child(1) > div:nth-child(5)"],
    "mode" : "1"
  },
  "/offers.html" : {
    "selectors" : ["#primary > div > div:nth-child(3)"],
    "mode" : "1"
  },
}
if (PulseInsightsObject.survey !== null && PulseInsightsObject.survey.attributes.survey_type === 1 && PulseInsightsObject.survey.attributes.inline_target_selector == "null"){
  try {
    PulseInsightsObject.survey.attributes.inline_target_selector = selectorMap[window.location.pathname].selectors[0];
    PulseInsightsObject.survey.attributes.inline_target_position = selectorMap[window.location.pathname].mode;
    if(selectorMap[window.location.pathname].selectors.length === 2){
      PulseInsightsObject.survey.attributes.mobile_inline_target_selector = selectorMap[window.location.pathname].selectors[1];
    }
    else{
      PulseInsightsObject.survey.attributes.mobile_inline_target_selector = selectorMap[window.location.pathname].selectors[0];
    }
  } catch (e) {
    console.log(e);
  }
}
