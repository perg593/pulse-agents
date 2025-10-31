import {InvitationNodeWidget} from './InvitationNodeWidget';
import {InvitationNodeModel} from './InvitationNodeModel';
import * as React from 'react';
import {AbstractReactFactory} from '@projectstorm/react-canvas-core';
import {DiagramEngine} from '@projectstorm/react-diagrams-core';

/**
 * The glue that holds InvitationNodeWidgets (the Visual component), and
 * InvitationModel (the Model component). Together,
 * these represent a single node.
*/
export class InvitationNodeFactory extends
  AbstractReactFactory<InvitationNodeModel, DiagramEngine> {
  /**
   * Initializes the InvitationNodeFactory
  */
  constructor() {
    super('invitation');
  }

  /**
   * Generates React widgets from the model contained in the event object
   * @param { GenerateWidgetEvent<T> } event
   * @return { JSX.Element }
  */
  generateReactWidget(event): JSX.Element {
    return (
      <InvitationNodeWidget
        node={event.model.cleanUp()}
        engine={this.engine}
        size={50}
      />
    );
  }

  /**
   * Generates the node model's placeholder
   * @param { GenerateWidgetEvent<T> } event
   * @return { InvitationNodeModel }
  */
  generateModel(event) {
    return new InvitationNodeModel();
  }
}
