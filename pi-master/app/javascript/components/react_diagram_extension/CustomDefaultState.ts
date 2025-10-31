import {MouseEvent} from 'react';

import {
  SelectingState, State, Action, InputType, ActionEvent, DragCanvasState, MoveItemsState,
} from '@projectstorm/react-canvas-core';

import {
  PortModel, DiagramEngine, DragDiagramItemsState,
} from '@projectstorm/react-diagrams-core';

import {
  eventInModal,
  eventInClass,
} from '../survey_editor/ModalDetection';

import {CreateLinkState} from './CreateLinkState';
import {SelectLinkState} from './SelectLinkState';
import {CustomMoveItemsState} from './CustomMoveItemsState';

import {QuestionLinkModel} from './QuestionLinkModel';

export interface CustomDefaultStateOptions {
  dragCanvasStateOptions?: {}
  createLinkStateOptions?: {}
}

/**
 * Borrowed from the react-diagrams demos.
 * https://github.com/projectstorm/react-diagrams/blob/master/diagrams-demo-gallery/demos/demo-alternative-linking/DefaultState.ts
 * This creates a new DefaultState for use by the diagram engine.
 * We use this to customize behaviour, for example, with CreateLinkState.
 * Also allows us to prevent default behaviour based on context,
 * (e.g. open modal)
*/
export class CustomDefaultState extends State<DiagramEngine> {
  dragCanvas: DragCanvasState;
  createLink: CreateLinkState;
  dragItems: DragDiagramItemsState;

  /**
   * Initializes CustomDefaultState
   *
   * @param {CustomDefaultStateOptions} options
   */
  constructor(options: CustomDefaultStateOptions = {}) {
    super({name: 'starting-state'});
    this.childStates = [new SelectingState()];
    this.dragCanvas = new DragCanvasState(options.dragCanvasStateOptions);
    this.createLink = new CreateLinkState(options.createLinkStateOptions);
    this.dragItems = new CustomMoveItemsState(options.dragNodeStateOptions);
    this.defaultDragItems = new MoveItemsState();
    this.selectLink = new SelectLinkState();

    // determine what was clicked on
    this.registerAction(
        new Action({
          type: InputType.MOUSE_DOWN,
          fire: (event: ActionEvent<MouseEvent>) => this.onMouseDown(event),
        }),
    );

    this.registerAction(
        new Action({
          type: InputType.MOUSE_UP,
          fire: (event: ActionEvent<MouseEvent>) => this.onMouseUp(event),
        }),
    );
  }

  /**
   * OnMouseDown handler
   * Fires when the mouse goes down on the canvas
   * @param {ActionEvent} actionEvent - onMouseDown details
   */
  onMouseDown(actionEvent) {
    if (eventInModal(actionEvent)) {
      return;
    }

    if (eventInClass(actionEvent, 'handles-icon')) {
      return;
    }

    if (actionEvent.event.button !== 0) {
      return;
    }

    const element =
      this.engine.getActionEventBus().getModelForEvent(actionEvent);
    const diagramModel = this.engine.getModel();

    // the canvas was clicked on, transition to the dragging canvas state
    if (!element) {
      this.transitionWithEvent(this.dragCanvas, actionEvent);
    } else if (element instanceof PortModel) {
      // initiate dragging a new link
      return;
    } else if (element instanceof QuestionLinkModel) {
      this.transitionWithEvent(this.selectLink, actionEvent);
    } else {
      // move the items (and potentially link points)
      if (diagramModel.allAtOnceMode) {
        this.transitionWithEvent(this.dragItems, actionEvent);
      } else {
        this.transitionWithEvent(this.defaultDragItems, actionEvent);
      }
    }
  }

  /**
   * OnMouseUp handler
   * Fires when the mouse goes up on the canvas
   * @param {ActionEvent} actionEvent - onMouseUp details
   */
  onMouseUp(actionEvent) {
    const element =
      this.engine.getActionEventBus().getModelForEvent(actionEvent);

    if (element instanceof PortModel) {
      this.transitionWithEvent(this.createLink, actionEvent);
    }
  }
}
