import {
  DefaultPortModel,
  PortModelAlignment,
  RightAngleLinkModel,
} from '@projectstorm/react-diagrams';

import {QuestionLinkModel} from './QuestionLinkModel';

/**
 * A simple subclass of the default port model which uses
 * right angle links by default
 */
class RightAnglePortModel extends DefaultPortModel {
  createLinkModel(factory?: AbstractModelFactory<LinkModel>) {
    return new RightAngleLinkModel();
  }
}

/**
 * The custom port model for QuestionNodes
 */
export class QuestionPortModel extends RightAnglePortModel {
  data: Object; // either question or possible answer
  activeColor: string;
  defaultColor: string;
  useActiveColor: boolean;
  linkProximate: boolean; // whether a link is being dragged near this port

  /**
   * Initializes the port model
   * @param { PortModelAlignment } alignment -
   *   The side of the node the port sits on
   * @param { boolean } isInputPort -
   *   true if source of links,
   *   false if recipient of lnks.
   * @param { string } name - a unique name for the port. Defaults to alignment
   * @param { string } type - the port's type (e.g. question, invitation, etc.)
   * @param { Object } data - data associated with the card
   *   (e.g. question, invitation)
   */
  constructor(
      alignment: PortModelAlignment,
      isInputPort: boolean,
      name: string,
      type: string,
      data: Object,
  ) {
    super({
      type: type,
      name: name || alignment,
      alignment: alignment,
      in: isInputPort,
    });

    this.data = data;
    this.activeColor = '#000';
    this.defaultColor = '#7f7f7f';
    this.useActiveColor = false;
    this.linkProximate = false;
  }

  /**
   * @param { boolean } linkProximate - Set to true when dragging a link nearby
   */
  setLinkProximate(linkProximate : boolean) {
    this.linkProximate = linkProximate;
  }

  /**
   * @param { string } newColor - Sets the active colour (#RRGGBB)
   */
  setActiveColor(newColor: string) {
    this.activeColor = newColor;
  }

  /**
   * @param { boolean } newState - Whether or not to use active colour
   */
  setUseActiveColor(newState : boolean) {
    this.useActiveColor = newState;
  }

  /**
   * @return { string } - The colour we should be using
   */
  currentColor(): string {
    const usingActiveColor = this.useActiveColor && Object.keys(this.links).length > 0;

    return usingActiveColor ? this.activeColor : this.defaultColor;
  }

  /**
   * Creates a link (vertex) for the port
   * @return { LinkModel }
   */
  createLinkModel(): LinkModel {
    return new QuestionLinkModel();
  }

  /**
   * TODO: Now that dangling links are forbidden, do we even need this helper?
   * @return { bigint } the number of links
   */
  numCompleteLinks(): bigint {
    return Object.values(this.links).filter((link) => link.targetPort != null).length;
  }

  /**
   * @return { QuestionPortModel } the port (if any) that we are connected to
   */
  targetPort(): QuestionPortModel {
    // should be at most one
    const link = Object.values(this.links).find((link) => link.targetPort != null);
    return link ? link.targetPort : null;
  }

  /**
   * @param { QuestionPortModel } other - the port to link to
   * @return { bool } whether or not this port can link to the provided port
   */
  canLinkToPort(other: QuestionPortModel): boolean {
    const rightType = other instanceof QuestionPortModel;
    const outToIn = this.options.in !== other.getOptions().in;
    const differentNode = this.parent !== other.parent;
    const oneLink = this.options.in ? other.numCompleteLinks() < 1 : this.numCompleteLinks() < 1;

    if (!rightType) {
      console.debug('Failed to link: other port was of wrong type');
    }

    if (!outToIn) {
      console.debug('Failed to link: IN/OUT mismatch');
    }

    if (!differentNode) {
      console.debug('Failed to link: other port is on same node');
    }

    if (!oneLink) {
      console.debug('Failed to link: this port already has a link', this.links);
    }

    return rightType && outToIn && differentNode && oneLink;
  }

  /**
   * Remove all links from this port
  */
  removeLinks(): void {
    Object.values(this.links).forEach((link) => {
      link.remove();
    });
  }

  /**
   * Serializes the model
   * @return { Object }
  */
  serialize() {
    return ({
      ...super.serialize(),
      data: this.data,
      activeColor: this.activeColor,
      useActiveColor: this.useActiveColor,
      linkProximate: this.linkProximate,
    });
  }
}
