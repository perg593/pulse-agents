window.PulseInsightsLibrary = {};

/**
 * Returns text with HTML characters escaped
 *
 * @param {string} text
 * @return {string}
 **/
window.PulseInsightsLibrary.escapeText = function(text) {
  const div = document.createElement('div');

  div.appendChild(document.createTextNode(text));

  return div.innerHTML;
};

/**
 * Scans text for markdown-like annotations and replaces them with tags
 *
 * _text_ => <em>text</em>
 * *text* => <b>text</b>
 * ^text^ => <sup>text</sup>
 * ~text~ => <sub>text</sub>
 *
 * @param {string} text
 * @return {string}
 **/
window.PulseInsightsLibrary.formatText = function(text) {
  let formattedText = window.PulseInsightsLibrary.escapeText(text);

  // text wrapped in underscores
  formattedText = formattedText.replace(/_([^_]+)_/g, '<em>$1</em>');

  // text wrapped in asterisks
  formattedText = formattedText.replace(/\*([^\*]+)\*/g, '<b>$1</b>');

  // text wrapped in carets
  formattedText = formattedText.replace(/\^([^\^]+)\^/g, '<sup>$1</sup>');

  // text wrapped in tildes
  formattedText = formattedText.replace(/\~([^\~]+)\~/g, '<sub>$1</sub>');

  return formattedText;
};

window.PulseInsightsLibrary.getParam = (key) => {
  return new URLSearchParams(window.location.search).get(key);
};
