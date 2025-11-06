var answerLength, charactersCountLabel, charactersCountLabelText, charactersCountLabelTextNode, maxLength, remainingCharacters;
            if (answerLength = input.value.length,
            0 !== (maxLength = (charactersCountLabel = input.nextSibling).getAttribute("data-max-length")))
                return charactersCountLabelText = 1 === (remainingCharacters = maxLength - answerLength) ? "1 character left" : remainingCharacters + " characters left",
                charactersCountLabelTextNode = document.createTextNode(charactersCountLabelText),
                charactersCountLabel.innerHTML = "",
                charactersCountLabel.appendChild(charactersCountLabelTextNode),
                event && event.target && event.target.parentNode && event.target.parentNode.parentNode.setAttribute("data-answer", event.target.value),
                remainingCharacters > 0 && remainingCharacters < 20 ? (charactersCountLabel.setAttribute("class", "_pi_free_text_question_characters_count danger"),
                this.submitButton.removeAttribute("disabled")) : remainingCharacters < 0 ? (charactersCountLabel.setAttribute("class", "_pi_free_text_question_characters_count error"),
                this.submitButton.setAttribute("disabled", "disabled"),
                event && event.target && event.target.parentNode ? event.target.parentNode.parentNode.setAttribute("data-answer", "") : void 0) : (charactersCountLabel.setAttribute("class", "_pi_free_text_question_characters_count"),
                this.submitButton.removeAttribute("disabled"))

var updateCharCount = function(max, current, displayEl){
  displayEl.innerHTML = current + '/' + max;
};
var textInputs = document.querySelectorAll("._pi_free_text_question_field"),
    charCountEl,
    maxChars;
for (var i = 0; i < textInputs.length; i++) {
  el = textInputs[i];
  charCountEl = el.nextSibling;
  maxChars = charCountEl.getAttribute('data-max-length');
  el.setAttribute('maxLength', maxChars);
  charCountEl.style.setProperty('display', 'none');
  var newCharCountEl = document.createElement('div');
  newCharCountEl.setAttribute('class', '_pi_free_text_question_characters_count');
  el.parentNode.appendChild(newCharCountEl);
  el.addEventListener('keyup', function(e){updateCharCount(maxChars, el.value.length, newCharCountEl)});
  el.addEventListener('keypress', function(e){updateCharCount(maxChars, el.value.length, newCharCountEl)});
}
