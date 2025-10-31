import {RightAngleLinkModel} from '@projectstorm/react-diagrams';

/**
 * The data model representing all links between cards
*/
export class QuestionLinkModel extends RightAngleLinkModel {
  activeColor: string;
  useActiveColor: boolean;
  originalColor: string;
  hidden: boolean;

  /**
   * Initializes the QuestionNodeModel
   * @param { boolean } hidden - whether or not the link should be visible
   * (used by all-at-once mode)
   */
  constructor(hidden :boolean) {
    super({
      type: 'questionLink',
      width: 1,
    });

    this.activeColor = '#000';
    this.useActiveColor = false;
    this.originalColor = this.options.color;
    this.hidden = hidden;
  }

  /**
   * Initializes the QuestionNodeModel
   * @param { string } newColor - the colour to use when the link is active
   */
  setActiveColor(newColor: string) {
    this.activeColor = newColor;
  }

  /**
   * Initializes the QuestionNodeModel
   * @param { boolean } newState - whether or not to use the active colour
   */
  setUseActiveColor(newState: boolean) {
    this.useActiveColor = newState;

    if (newState) {
      this.options.color = this.activeColor;
    } else {
      this.options.color = this.originalColor;
    }
  }

  /**
   * Serializes the model
   * @return { Object }
  */
  serialize() {
    return ({
      ...super.serialize(),
      activeColor: this.activeColor,
      useActiveColor: this.useActiveColor,
      originalColor: this.originalColor,
      hidden: this.hidden,
    });
  }
}
