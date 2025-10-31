import {
  DefaultNodeModel, NodeModelGenerics, PortModelAlignment,
} from '@projectstorm/react-diagrams';

import {QuestionPortModel} from './QuestionPortModel';

export interface InvitationNodeModelGenerics {
  PORT: QuestionPortModel;
}

/**
 * The data model representing everything in an
 * InvitationNode (aka Invitation Card)
*/
export class InvitationNodeModel
  extends DefaultNodeModel<NodeModelGenerics & InvitationNodeModelGenerics> {
  invitation: Object;
  persistentDiagramProperties: Object;
  dirty: boolean;
  hidePorts: boolean;
  deleted: boolean;

  /**
   * Initializes the ThankYouNodeModel
   * @param { string } invitation - the invitation message
   *   on survey completion
   * @param { string } invitationButton - the label of the invitation button
   *   on survey completion
   * @param { boolean } invitationButtonDisabled - whether or not to the
   *   invitation button will be shown
   * @param { Object } persistentDiagramProperties - diagram settings that
   *   are stored in the db. (e.g. node position)
   */
  constructor(
      invitation: string,
      invitationButton: string,
      invitationButtonDisabled: boolean,
      persistentDiagramProperties: Object,
      hidePorts: boolean,
  ) {
    super({
      type: 'invitation',
    });

    this.invitation = {
      invitation: invitation,
      invitationButton: invitationButton,
      invitationButtonDisabled: invitationButtonDisabled,
    };

    const port = new QuestionPortModel(
        PortModelAlignment.RIGHT,
        false,
        null,
        'questionOutPort',
        null,
    );
    this.addPort(port);

    this.persistentDiagramProperties = persistentDiagramProperties;
    this.setPosition(...this.persistentDiagramProperties.position);

    this.hidePorts = hidePorts;
    this.deleted = false;
    this.dirty = false;
  }

  /**
   * Convenience method to retrieve the OUT port
   * @return { QuestionPortModel } the model's OUT port
   */
  getStartPort() : QuestionPortModel {
    return this.getPort(PortModelAlignment.RIGHT);
  }

  /**
   * Doesn't actually remove the model from the diagram.
   * We want to keep this model around because it simplifies repeated
   * addition/deletion of the invitation (of which there can only be one)
   */
  delete() {
    this.deleted = true;
  }

  /**
   * This should undo whatever delete does
   */
  undelete() {
    this.deleted = false;
  }

  /**
   * Forces a re-render by toggling a serialized value
   */
  makeDirty() {
    this.dirty = true;
  }

  /**
   * Reset dirty to false
   * @return { InvitationNodeModel }
   */
  cleanUp() {
    this.dirty = false;
    return this;
  }

  /**
   * Updates our internal invitation object
   * @param { Object } newValues - the object containing new thankYou data
   */
  updateInvitation(newValues: Object) {
    // Need to make a new object. Manipulating the old one won't be recognized
    // as a change by the serializer
    this.invitation = {
      ...this.invitation,
      ...newValues,
    };
  }

  /**
   * Serializes the model
   * @return { Object }
  */
  serialize() {
    return {
      ...super.serialize(),
      invitation: this.invitation,
      dirty: this.dirty,
      hidePorts: this.hidePorts,
      deleted: this.deleted,
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
