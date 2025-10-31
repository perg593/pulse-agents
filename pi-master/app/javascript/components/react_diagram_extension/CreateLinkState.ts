import {
  Action, InputType, State,
} from '@projectstorm/react-canvas-core';

import {
  PortModel,
} from '@projectstorm/react-diagrams-core';

import {QuestionNodeModel} from './QuestionNodeModel';
import {InvitationNodeModel} from './InvitationNodeModel';

/**
 * Gets the scale of the svg canvas' affine transformation.
 * @param { JSX.element } element - the svg canvas element
 * @return { bigint } the transform's scale
 */
function getScaleValue(element) {
  const style = window.getComputedStyle(element);
  const matrix = style.transform;

  // No transform property. Scale is 1.
  if (matrix === 'none') {
    return 1;
  }

  const matrixValues = matrix.match(/matrix.*\((.+)\)/)[1].split(', ');

  return Number(matrixValues[0]);
}

export interface CreateLinkStateOptions {
  // Prevent the creation or modification of links
  lockLinkModification?: boolean;
}

/**
 * Borrowed from https://github.com/projectstorm/react-diagrams/issues/709
 * This is an improvement (a fix, really) on the react-diagrams demo.
 */
export class CreateLinkState extends State {
  candidateInputPorts: QuestionPortModel[];
  nearbyPorts: QuestionPortModel[];
  link: QuestionLinkModel;
  sourcePort: QuestionPortModel;
  locked: boolean;

  /**
   * Initializes the CreateLinkState
   *
   * @param {CustomDefaultStateOptions} options
   */
  constructor(options: CreateLinkStateOptions) {
    super({name: 'create-new-link'});

    this.candidateInputPorts = [];
    this.nearbyPorts = [];
    this.locked = options.lockLinkModification;

    this.registerAction(
        new Action({
          type: InputType.MOUSE_UP,
          fire: (actionEvent) => this.onMouseUp(actionEvent),
        }),
    );

    this.registerAction(
        new Action({
          type: InputType.MOUSE_MOVE,
          fire: (actionEvent) => this.onMouseMove(actionEvent),
        }),
    );

    this.registerAction(
        new Action({
          type: InputType.KEY_UP,
          fire: (actionEvent) => this.onKeyUp(actionEvent),
        }),
    );
  }

  /**
   * OnMouseUp handler
   * Fires when the mouse goes up on the canvas
   * @param {ActionEvent} actionEvent - onMouseUp details
   */
  onMouseUp(actionEvent) : void {
    if (this.locked) {
        this.eject();
        return;
    }

    const element = this.engine.getActionEventBus().
        getModelForEvent(actionEvent);

    if (element instanceof PortModel) {
      if (!this.sourcePort && !element.options.in) {
        this.beginLink(element);
        this.engine.repaintCanvas();
      } else if (this.sourcePort && element !== this.sourcePort &&
                   this.sourcePort.canLinkToPort(element)) {
        this.completeLink(element);
        this.engine.repaintCanvas();
      } else {
        this.eject();
      }
    }
  }

  /**
   * OnMouseMove handler
   * Fires when the mouse moves on the canvas
   * @param {ActionEvent} actionEvent onMouseUp details
   */
  onMouseMove(actionEvent) : void {
    if (!this.link) {
      return;
    }

    const {event} = actionEvent;

    const {clientX, clientY} = event;
    const svgCanvas = document.querySelector('svg');
    const clientRect = svgCanvas.getBoundingClientRect();
    const scale = getScaleValue(svgCanvas);

    const viewportX = (clientX - clientRect.x) / scale;
    const viewportY = (clientY - clientRect.y) / scale;

    this.link.getLastPoint().setPosition(viewportX, viewportY);

    this.styleNearbyPorts(viewportX, viewportY);

    this.engine.repaintCanvas();
  }

  /**
   * Handles KeyUp events.
   * Only used to cancel link creation.
   * @param {ActionEvent} actionEvent - KeyUp details
   */
  onKeyUp(actionEvent) : void {
    if (actionEvent.event.key === 'Escape') {
      if (this.sourcePort.parent instanceof InvitationNodeModel) {
        // Reconnect it to the old first question
        const link = this.sourcePort.createLinkModel();
        link.setSourcePort(this.sourcePort);

        const firstQuestion = this.engine.getModel().getQuestionNodesInPositionOrder()[0];
        const targetPort = firstQuestion.getQuestionInputPort();

        link.setTargetPort(targetPort);
        this.engine.getModel().addLink(link);

        this.sourcePort.reportPosition();
        targetPort.reportPosition();
      }

      this.link.remove();
      this.clearState();
      this.eject();
      this.engine.repaintCanvas();
    }
  }

  private

  /**
   * Starts a link
   * @param {QuestionPortModel} element - the source port
   */
  beginLink(element) {
    this.engine.getModel().clearSelection();
    element.parent.setSelected(true);

    this.sourcePort = element;

    // destroy old link
    this.sourcePort.removeLinks();

    const nodes = this.engine.getModel().getNodes();
    const questionNodes = nodes.filter((node) => {
      return node instanceof QuestionNodeModel &&
        node != this.sourcePort.parent;
    });

    this.candidateInputPorts = questionNodes.map((questionNode) => {
      return questionNode.getQuestionInputPort();
    });

    const link = this.sourcePort.createLinkModel();
    link.setSourcePort(this.sourcePort);

    link.getFirstPoint().setPosition(
        this.sourcePort.position.x + (this.sourcePort.width / 2),
        this.sourcePort.position.y + (this.sourcePort.height / 2),
    );

    link.getLastPoint().setPosition(
        this.sourcePort.position.x + 20,
        this.sourcePort.position.y + 20,
    );

    this.link = this.engine.getModel().addLink(link);
  }

  /**
   * Finishes a link
   * @param {QuestionPortModel} element - the target port
   */
  completeLink(element) {
    this.link.setTargetPort(element);

    if (this.sourcePort.parent instanceof InvitationNodeModel) {
      this.engine.getModel().handleLinkCreation(this.sourcePort);
    }

    this.sourcePort.parent.makeDirty();

    element.reportPosition();
    this.clearState();
    this.eject();
  }

  /**
   * Determines which ports are nearby and changes their styles
   * @param {number} viewportX - the mouse's X position in viewport space
   * @param {number} viewportY - the mouse's Y position in viewport space
   */
  styleNearbyPorts(viewportX :number, viewportY :number) {
    // calculate distance to each port
    const portsAndDistances = this.candidateInputPorts.map((port) => {
      const squaredDistance =
          (viewportX - port.position.x) ** 2 +
          (viewportY - port.position.y) ** 2;

      return {port: port, squaredDistance: squaredDistance};
    });

    const proximityThreshold = 5000;

    this.nearbyPorts = portsAndDistances.filter((portAndDistance) => {
      return portAndDistance.squaredDistance <= proximityThreshold;
    }).map((portAndDistance) => portAndDistance.port);

    // style all ports in proximity
    this.nearbyPorts.forEach((port) => port.setLinkProximate(true));

    // unstyle all ports out of reach
    portsAndDistances.filter((portAndDistance) => {
      return portAndDistance.squaredDistance > proximityThreshold;
    }).map((portAndDistance) => portAndDistance.port).forEach((port) => {
      port.setLinkProximate(false);
    });
  }

  /**
   * Resets our instance variables.
   */
  clearState() {
    this.link = undefined;
    this.sourcePort = undefined;
    this.candidateInputPorts = [];
    this.nearbyPorts.forEach((port) => port.setLinkProximate(false));
    this.nearbyPorts = [];
  }
}
