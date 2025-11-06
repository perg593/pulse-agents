pi_nav = PulseInsightsObject.survey;

function displayProductsId() {
   pi_nav.destroy();
   pi_nav.attributes.inline_target_selector = '#ProductsIdSubNav';
   pi_nav.render();
}

function displayCreditEducationId() {
   pi_nav.destroy();
   pi_nav.attributes.inline_target_selector = '#CreditEducationIdSubNav';
   pi_nav.render();
}

function displayCreditReportAssistanceId() {
   pi_nav.destroy();
   pi_nav.attributes.inline_target_selector = '#CreditReportAssistanceIdSubNav';
   pi_nav.render();
}

function displayCreditOffersId() {
   pi_nav.destroy();
   pi_nav.attributes.inline_target_selector = '#CreditOffersIdSubNav';
   pi_nav.render();
}

function displayToolsId() {
   pi_nav.destroy();
   pi_nav.attributes.inline_target_selector = '#ToolsIdSubNav';
   pi_nav.render();
}

nav_attr = pi_nav.attributes.id;
nav_sID = 2583;

document.getElementsByClassName('toggleMenu')[0].onclick = function() { if (nav_attr == nav_sID) {displayProductsId()} };
document.getElementsByClassName('toggleMenu')[1].onclick = function() { if (nav_attr == nav_sID) {displayCreditEducationId()} };
document.getElementsByClassName('toggleMenu')[2].onclick = function() { if (nav_attr == nav_sID) {displayCreditReportAssistanceId()} };
document.getElementsByClassName('toggleMenu')[3].onclick = function() { if (nav_attr == nav_sID) {displayCreditOffersId()} };
document.getElementsByClassName('toggleMenu')[4].onclick = function() { if (nav_attr == nav_sID) {displayToolsId()} };
