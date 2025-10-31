/**
 * Position the hover menu
 * @param {MouseEvent} e
 * @param {number} popupHeight
 *
 * @return {number[]} - [x, y]
 */
function popupPosition(e: MouseEvent, popupHeight: number) : number[] {
  let popupY = e.pageY;
  const screenSpaceY = e.pageY - window.pageYOffset;

  // If there is not enough room below the click to show the popup,
  // show it above the click instead.
  const distanceFromBottom = (window.innerHeight - screenSpaceY);

  if (distanceFromBottom < popupHeight) {
    popupY = e.pageY - popupHeight + distanceFromBottom;
  }

  return [e.pageX, popupY];
}

export {popupPosition};
