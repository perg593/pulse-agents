import {ThankYouNodeWidget} from './ThankYouNodeWidget';
import {ThankYouNodeModel} from './ThankYouNodeModel';
import * as React from 'react';
import {AbstractReactFactory} from '@projectstorm/react-canvas-core';
import {DiagramEngine} from '@projectstorm/react-diagrams-core';

/**
 * The glue that holds ThankYouNodeWidgets (the Visual component), and
 * ThankYouModel (the Model component). Together these represent a single node.
*/
export class ThankYouNodeFactory extends
  AbstractReactFactory<ThankYouNodeModel, DiagramEngine> {
  /**
   * Initializes the ThankYouNodeFactory
  */
  constructor() {
    super('thankYou');
  }

  /**
   * Generates React widgets from the model contained in the event object
   * @param { GenerateWidgetEvent<T> } event
   * @return { JSX.Element }
  */
  generateReactWidget(event): JSX.Element {
    return (
      <ThankYouNodeWidget
        node={event.model.cleanUp()}
        engine={this.engine}
        size={50}
      />
    );
  }

  /**
   * Generates the node model's placeholder
   * @param { GenerateWidgetEvent<T> } event
   * @return { ThankYouNodeModel }
  */
  generateModel(event) {
    return new ThankYouNodeModel();
  }
}
