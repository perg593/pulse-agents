/**
 * @param {Event} event
 * @param {string} className
 * @return {bool} whether or not the event took place in (or in a child of)
 * an element with class className
 */
export function eventInClass(event: Event, className: string) : boolean {
  let parentElement = event.event.target;
  while (parentElement) {
    if (hasClass(parentElement, className)) {
      break;
    }
    parentElement = parentElement.parentElement;
  }

  return hasClass(parentElement, className);
}

/**
 * @param {Event} event
 * @return {bool} whether or not the event took place in a modal
 */
export function eventInModal(event: Event) : boolean {
  return eventInClass(event, 'modal');
}

/**
 * @param {Element} element
 * @param {string} className
 * @return {bool} whether or not the element has the given class name
 */
function hasClass(element: Element, className: string) : boolean {
  return element &&
    element.getAttribute('class') &&
    element.getAttribute('class').indexOf(className) != -1;
}
