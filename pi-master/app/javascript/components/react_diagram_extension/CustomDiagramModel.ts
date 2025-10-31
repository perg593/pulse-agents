import {DiagramModel} from '@projectstorm/react-diagrams';
import {DeserializeEvent} from '@projectstorm/react-canvas-core';

import {InvitationNodeModel} from './InvitationNodeModel';
import {QuestionNodeModel} from './QuestionNodeModel';
import {ThankYouNodeModel} from './ThankYouNodeModel';

export interface CustomDiagramModelOptions {
  // "All at once" hides ports and links, and restricts node movement
  // to reordering, which changes questions.position
  allAtOnceMode: boolean;
  lockStructuralChanges: boolean;
  readOnly: boolean;
}

/**
 * Overrides DiagramModel to provide some extra attributes
 * and convenience methods.
 */
export class CustomDiagramModel extends DiagramModel {
  allAtOnceMode: boolean;
  lockStructuralChanges: boolean;
  readOnly: boolean;

  /**
   * Initializes the CustomDiagramModel
   * @param {CustomDiagramModelOptions} options
  */
  constructor(options: CustomDiagramModelOptions) {
    super();

    this.allAtOnceMode = options.allAtOnceMode;
    this.lockStructuralChanges = options.lockStructuralChanges;
    this.setZoomLevel(100);
    this.readOnly = options.readOnly;
  }

  /**
   * Override the default. 80 is the new 100.
   *
   * Ideally this would simply override getZoomLevel, but that
   * conflicts with the internals of react-diagrams.
   *
   * @return {number} 20 higher than the default
   */
  getDisplayZoomLevel() : number {
    return super.getZoomLevel() + 20;
  }

  /**
   * Override the default. 80 is the new 100.
   * @param {number} newVal - the new zoom level
   */
  setZoomLevel(newVal: number) {
    super.setZoomLevel(newVal - 20);
  }

  /**
   * Deserializes the model
   * @param { DeserializeEvent<this> } event
  */
  deserialize(event: DeserializeEvent<this>) {
    super.deserialize(event);
  }

  /**
   * A convenience function to get all question node models
   * @return { Array } an array of QuestionNodeModel
   */
  getQuestionNodes() {
    return this.getNodes().filter((node) => {
      return node instanceof QuestionNodeModel;
    });
  }

  /**
   * A convenience function to get all question node models
   * in order of questions.position
   * @return {Array<QuestionNodeModel>} an array of QuestionNode models,
   */
  getQuestionNodesInPositionOrder() {
    return this.getQuestionNodes().sort((a, b) => {
      return a.question.position - b.question.position;
    });
  }

  /**
   * A convenience function to get the invitation node model
   * @return { InvitationNodeModel } the invitation node model
   */
  getInvitationNode() {
    return this.getNodes().find((node) => {
      return node instanceof InvitationNodeModel;
    });
  }

  /**
   * A convenience function to get the thank you node model
   * @return { ThankYouNodeModel } the thank you node model
   */
  getThankYouNode() {
    return this.getNodes().find((node) => {
      return node instanceof ThankYouNodeModel;
    });
  }

  /**
   * Assigns the invitation/start node a new first node
   */
  assignNewFirstQuestion() {
    const newFirstNode = this.getQuestionNodesInPositionOrder()[0];
    const startPort = this.getInvitationNode().getStartPort();

    const oldTargetPort = startPort.targetPort();
    const newTargetPort = newFirstNode.getQuestionInputPort();

    if (newTargetPort === oldTargetPort) {
      return;
    }

    const link = Object.values(startPort.links)[0];

    if (link) {
      link.setTargetPort(newTargetPort);

      newTargetPort.reportedPosition = false;
    } else {
      const newLink = startPort.link(newTargetPort);

      startPort.reportedPosition = false;
      newTargetPort.reportedPosition = false;

      this.addLink(newLink);
    }
  }

  /**
   * When a link is created we must designate the target question node as
   * the new first question, and change the positions of all questions preceding
   * it accordingly.
   */
  handleLinkCreation(port) {
    const newFirstQuestion = port.targetPort().parent;
    const originalPosition = newFirstQuestion.question.position;

    const precedingQuestionNodesByPosition = this.getQuestionNodesInPositionOrder().filter((questionNode) => {
      return questionNode.question.position < originalPosition;
    });

    // This question is already the first question
    if (precedingQuestionNodesByPosition.length === 0) {
      console.debug('already first, no change necessary');
      return;
    }

    const lowestQuestionPosition = precedingQuestionNodesByPosition[0].
        question.position;

    precedingQuestionNodesByPosition.forEach((questionNode) => {
      const newPosition = questionNode.question.position + 1;
      questionNode.updateQuestion({position: newPosition});
    });

    newFirstQuestion.updateQuestion({position: lowestQuestionPosition});
  }

  /**
   * Enforce question position constraints:
   * - 0-based
   * - no duplicates
   * - no gaps
   */
  defragmentQuestionPositions () {
    this.getQuestionNodesInPositionOrder().forEach((node, i) => {
      node.updateQuestion({position: i})
    });
  }
}
