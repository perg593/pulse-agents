import {WheelEvent} from 'react';

import {
  Action,
  ActionEvent,
  InputType,
} from '@projectstorm/react-canvas-core';

import {eventInModal} from '../survey_editor/ModalDetection';

export interface ZoomCanvasActionOptions {
  inverseZoom?: boolean;
}

/**
 * Overrides react-diagram's mouse wheel handler
 * Copied from
 * https://github.com/projectstorm/react-diagrams/blob/master/packages/react-canvas-core/src/actions/ZoomCanvasAction.ts
 * Allow us to prevent default behaviour based on context, (e.g. open modal)
 */
export class CustomZoomCanvasAction extends Action {
  /**
   * Initializes the zoom handler
   * @param {ZoomCanvasActionOptions} options
   */
  constructor(options: ZoomCanvasActionOptions = {}) {
    super({
      type: InputType.MOUSE_WHEEL,
      fire: (actionEvent: ActionEvent<WheelEvent>) => this.onMouseWheel(actionEvent, options),
    });
  }

  /**
   * OnMouseWheel handler
   * Fires when the mouse wheel turns
   * @param {ActionEvent} actionEvent - onMouseWheel details
   * @param {Object} options - See
   * https://github.com/projectstorm/react-diagrams/blob/master/packages/react-canvas-core/src/actions/ZoomCanvasAction.ts
   */
  onMouseWheel(actionEvent, options) {
    if (eventInModal(actionEvent)) {
      return;
    }

    const model = this.engine.getModel();

    // Zooming with the mouse wheel conflicts with the scroll bar
    if (model.allAtOnceMode) {
      return;
    }

    const {event} = actionEvent;
    // we can block layer rendering because we are only targeting the transforms
    for (const layer of this.engine.getModel().getLayers()) {
      layer.allowRepaint(false);
    }

    event.stopPropagation();
    const oldZoomFactor = this.engine.getModel().getDisplayZoomLevel() / 100;
    let scrollDelta = options.inverseZoom ? -event.deltaY : event.deltaY;

    // check if it is pinch gesture
    if (event.ctrlKey && scrollDelta % 1 !== 0) {
      /*
         Chrome and Firefox sends wheel event with deltaY that
         have fractional part, also `ctrlKey` prop of the event is true
         though ctrl isn't pressed
       */
      scrollDelta /= 3;
    } else {
      scrollDelta /= 60;
    }

    if (model.getDisplayZoomLevel() + scrollDelta > 10) {
      model.setZoomLevel(model.getDisplayZoomLevel() + scrollDelta);
    }

    const zoomFactor = model.getDisplayZoomLevel() / 100;

    const boundingRect = event.currentTarget.getBoundingClientRect();
    const clientWidth = boundingRect.width;
    const clientHeight = boundingRect.height;
    // compute difference between rect before and after scroll
    const widthDiff = clientWidth * zoomFactor - clientWidth * oldZoomFactor;
    const heightDiff = clientHeight * zoomFactor - clientHeight * oldZoomFactor;
    // compute mouse coords relative to canvas
    const clientX = event.clientX - boundingRect.left;
    const clientY = event.clientY - boundingRect.top;

    // compute width and height increment factor
    const xFactor = (clientX - model.getOffsetX()) /
      oldZoomFactor / clientWidth;
    const yFactor = (clientY - model.getOffsetY()) /
      oldZoomFactor / clientHeight;

    model.setOffset(model.getOffsetX() - widthDiff * xFactor,
        model.getOffsetY() - heightDiff * yFactor);
    this.engine.repaintCanvas();

    // re-enable rendering
    for (const layer of this.engine.getModel().getLayers()) {
      layer.allowRepaint(true);
    }
  }
}
