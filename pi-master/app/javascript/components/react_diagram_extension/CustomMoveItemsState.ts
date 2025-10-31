import {
  MoveItemsState, Action, ActionEvent, InputType,
} from '@projectstorm/react-canvas-core';

import {
  BasePositionModel,
} from '@projectstorm/react-canvas-core';

import {QuestionNodeModel} from './QuestionNodeModel';

/**
 * -
 * |------------------- <- top
 * |
 * |------------------- <- bottom
 * +
 *
 * Used to help determine the droppable boundaries for nodes
 **/
class Lane {
  top: number;
  bottom: number;

  /**
   * @param {number} top -- the top position of the lane
   * @param {number} bottom -- the bottom position of the lane
   **/
  constructor(top: number, bottom: number) {
    this.top = top;
    this.bottom = bottom;
  }
}

export interface CustomMoveItemsStateOptions {
  allowDrag: boolean;
}

/**
 * A customized drag handler for react-diagrams
*/
export class CustomMoveItemsState<E extends CanvasEngine = CanvasEngine> extends MoveItemsState<E> {
  lanes: Array<Lane>;
  startingLaneIndex: number;
  validSelection: boolean;
  questionNodes: Array<QuestionNodeModel>;
  allowDrag: boolean;

  interlaneBuffer = 70;

  /**
   * Initializes CustomMoveItemsState
   */
  constructor(options: CustomMoveItemsStateOptions = {}) {
    super();

    this.allowDrag = options.allowDrag ?? true;

    this.registerAction(
        new Action({
          type: InputType.MOUSE_UP,
          fire: (event: ActionEvent<MouseEvent>) => this.onMouseUp(event),
        }),
    );

    this.registerAction(
        new Action({
          type: InputType.MOUSE_DOWN,
          fire: (event: ActionEvent<MouseEvent>) => this.onMouseDown(event),
        }),
    );

    this.lanes = [];
    this.startingLaneIndex = null;
    this.validSelection = false;
  }

  /**
   * Finds the lane index of a given node.
   * @param {QuestionNodeModel} node - the node whose lane index we seek
   * @return {number} index of the lane (-1 if not found)
   */
  private getLaneIndex(node: QuestionNodeModel) : number {
    const nodeY = node.position.y;

    if (nodeY <= this.lanes[0].top) {
      return 0;
    }

    if (nodeY > this.lanes[this.lanes.length - 1].bottom) {
      return this.lanes.length - 1;
    }

    return this.lanes.findIndex((lane) => {
      return lane.top < nodeY && nodeY <= lane.bottom - this.interlaneBuffer;
    });
  }

  /**
   * Get an array of nodes affected by a drop, in position order
   *
   * @param {number} newLaneIndex
   * @param {Node} nodeBeingMoved
   *
   * @return {Array} all nodes affected by the drop
   **/
  nodesToReorder(newLaneIndex: number, nodeBeingMoved: Node) {
    let nodesToShift = [];

    if (newLaneIndex > this.startingLaneIndex) {
      nodesToShift = [
        ...this.questionNodes.slice(this.startingLaneIndex + 1, newLaneIndex + 1),
        nodeBeingMoved,
      ];
    } else {
      nodesToShift = [
        nodeBeingMoved,
        ...this.questionNodes.slice(newLaneIndex, this.startingLaneIndex),
      ];
    }

    return nodesToShift;
  }

  /**
   * Reorders the nodes after drag and drop
   *
   * @param {number} newLaneIndex
   * @param {Node} nodeBeingMoved
   **/
  reorderNodes(newLaneIndex: number, nodeBeingMoved: Node) {
    const startingY = Math.min(
        this.lanes[this.startingLaneIndex].top,
        this.lanes[newLaneIndex].top,
    );

    const nodesToShift = this.nodesToReorder(newLaneIndex, nodeBeingMoved);

    let curY = startingY;
    const laneIndexDifference = newLaneIndex - this.startingLaneIndex;

    for (let i = 0; i < nodesToShift.length; i++) {
      const curNode = nodesToShift[i];

      curNode.setPosition(curNode.position.x, curY);

      curY += curNode.height

      // The node being moved will be rendering its footer, which
      // takes up the same amount of space as the interlaneBuffer
      // and is included in its height
      if (curNode !== nodeBeingMoved) {
        curY += this.interlaneBuffer;
      }

      const laneOffset = (curNode === nodeBeingMoved) ?
        laneIndexDifference : -Math.sign(laneIndexDifference);

      curNode.updateQuestion({
        position: curNode.question.position + laneOffset,
      });
    }

    const diagramModel = this.engine.getModel();
    diagramModel.defragmentQuestionPositions();

    // alert the diagram that there's a new first node in town
    if (this.startingLaneIndex == 0 || newLaneIndex == 0) {
      diagramModel.assignNewFirstQuestion();
    }
  }

  /**
   * OnMouseUp handler
   * Fires when the mouse goes up on the canvas
   * @param {ActionEvent} actionEvent - onMouseUp details
   */
  onMouseUp(actionEvent) {
    if (!this.validSelection) {
      return;
    }

    if (this.lanes.length === 0) {
      return;
    }

    const nodeBeingMoved = this.questionNodes.find((questionNode) => {
      return questionNode.isSelected();
    });

    const newLaneIndex = this.getLaneIndex(nodeBeingMoved);

    // now actually assign/force lane and redistribute space
    // need to adjust positions of cards in space between oldIndex and newIndex
    // the space is there, we just have to shuffle them around

    // moving down
    if (newLaneIndex === -1 || newLaneIndex === this.startingLaneIndex) {
      // force it back into its lane at its original y value
      const originalPosition = [
        nodeBeingMoved.position.x,
        this.lanes[this.startingLaneIndex].top,
      ];
      nodeBeingMoved.setPosition(...originalPosition);
    } else {
      this.reorderNodes(newLaneIndex, nodeBeingMoved);
    }
  }

  /**
   * OnMouseUp handler
   * Fires when the mouse goes down on the canvas
   * @param {ActionEvent} actionEvent - onMouseDown details
   */
  onMouseDown(actionEvent) {
    if (!this.allowDrag) {
      this.validSelection = false;
      return;
    }

    const diagramModel = this.engine.getModel();

    const items = diagramModel.getSelectedEntities();
    for (let item of items) {
      if (item instanceof BasePositionModel) {
        if (item.isLocked()) {
          // Don't really care about multiple selections because they're weird.

          this.validSelection = false;
          return;
        }
      }
    }

    this.validSelection = true;

    this.lanes = [];

    this.questionNodes = diagramModel.getQuestionNodesInPositionOrder();

    const selectedQuestionIndex = this.questionNodes.findIndex((node) => {
      return node.isSelected();
    });

    this.startingLaneIndex = selectedQuestionIndex;
  }

  /**
   * Builds the lanes which represent droppable areas for nodes
   **/
  buildLanes() {
    const diagramModel = this.engine.getModel();
    this.questionNodes = diagramModel.getQuestionNodesInPositionOrder();
    this.questionNodes.forEach((questionNode, questionPosition) => {
      let laneEnd = questionNode.position.y + questionNode.height;

      // The node being moved will be rendering its footer, which
      // takes up the same amount of space as the interlaneBuffer
      // and is included in its height
      if (!questionNode.isSelected()) {
        laneEnd += this.interlaneBuffer;
      }

      const curLane = new Lane(questionNode.position.y, laneEnd);

      this.lanes.push(curLane);
    });
  }

  /**
   * Used for debugging
   **/
  printLanes() {
    this.lanes.forEach((lane) => {
      console.debug(lane.top, lane.bottom, lane.bottom - lane.top);
    });
  }

  /**
   * Fires when the mouse is moved on the canvas
   * @param {AbstractDisplacementStateEvent} event - movement details
   */
  fireMouseMoved(event: AbstractDisplacementStateEvent) {
    if (!this.validSelection) {
      return;
    }

    const diagramModel = this.engine.getModel();
    const items = diagramModel.getSelectedEntities();

    // It's important to wait until we've started moving before building the lanes
    // because rendering lags behind mouse events. When we first click a node
    // we may still be rendering the footer of the previously selected node,
    // and our current selection may or may not have its footer rendered.
    if (this.lanes.length === 0) {
      this.buildLanes();
    }

    for (let item of items) {
      if (item instanceof BasePositionModel) {
        if (item.isLocked()) {
          continue;
        }
        if (!this.initialPositions[item.getID()]) {
          this.initialPositions[item.getID()] = {
            point: item.getPosition(),
            item: item
          };
        }

        const pos = this.initialPositions[item.getID()].point;

        const newX = pos.x; // We only allow movement on the y axis
        const newY = pos.y + event.virtualDisplacementY;

        item.setPosition(
            diagramModel.getGridPosition(newX),
            diagramModel.getGridPosition(newY),
        );
      }
    }

    this.engine.repaintCanvas();
  }
}
