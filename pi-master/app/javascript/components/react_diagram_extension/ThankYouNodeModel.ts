import {
  DefaultNodeModel, NodeModelGenerics,
} from '@projectstorm/react-diagrams';

/**
 * The data model representing everything in an ThankYouNode (aka ThankYou Card)
*/
export class ThankYouNodeModel
  extends DefaultNodeModel<NodeModelGenerics> {
  thankYou: Object;
  persistentDiagramProperties: Object;
  dirty: boolean;

  /**
   * Initializes the ThankYouNodeModel
   * @param { string } thankYou - the "thank you" message shown
   *   on survey completion
   * @param { boolean } pollEnabled - whether to show poll results instead of
   *   "thank you" message
   * @param { Object } persistentDiagramProperties - diagram settings that
   *   are stored in the db. (e.g. node position)
   */
  constructor(
      thankYou: string,
      pollEnabled: boolean,
      persistentDiagramProperties: Object,
  ) {
    super({
      type: 'thankYou',
    });

    this.thankYou = {
      thankYou: thankYou,
      pollEnabled: pollEnabled,
    };

    this.persistentDiagramProperties = persistentDiagramProperties;
    this.setPosition(...this.persistentDiagramProperties.position);

    this.dirty = false;
  }

  /**
   * Updates our internal ThankYou object
   * @param { Object } newValues - the object containing new thankYou data
   */
  updateThankYou(newValues: Object) {
    this.thankYou = {
      ...this.thankYou,
      ...newValues,
    };
  }

  /**
   * Forces a re-render by toggling a serialized value
   */
  makeDirty() {
    this.dirty = true;
  }

  /**
   * Reset dirty to false
   * @return { ThankYouNodeModel }
   */
  cleanUp() {
    this.dirty = false;
    return this;
  }

  /**
   * Serializes the model
   * @return { Object }
  */
  serialize() {
    return {
      ...super.serialize(),
      thankYou: this.thankYou,
      dirty: this.dirty,
    };
  }

  /**
   * Deserializes the model
   * @param { Object } data
   * @param { DiagramEngine } engine
  */
  deSerialize(data: any, engine: DiagramEngine) {
    super.deSerialize(data, engine);
  }
}
