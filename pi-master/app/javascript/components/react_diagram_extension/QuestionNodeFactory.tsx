import {QuestionNodeWidget} from './QuestionNodeWidget';
import {QuestionNodeModel} from './QuestionNodeModel';
import * as React from 'react';
import {AbstractReactFactory} from '@projectstorm/react-canvas-core';
import {DiagramEngine} from '@projectstorm/react-diagrams-core';

/**
 * The glue that holds QuestionNodeWidgets (the Visual component), and
 * QuestionModel (the Model component). Together these represent a single node.
*/
export class QuestionNodeFactory extends
  AbstractReactFactory<QuestionNodeModel, DiagramEngine> {

  setAllAtOncePositions: Function;

  /**
   * Initializes the QuestionNodeFactory
  */
  constructor(setAllAtOncePositions) {
    super('question');

    this.setAllAtOncePositions = setAllAtOncePositions;
  }

  /**
   * Generates React widgets from the model contained in the event object
   * @param { GenerateWidgetEvent<T> } event
   * @return { JSX.Element }
  */
  generateReactWidget(event): JSX.Element {
    return (
      <QuestionNodeWidget
        engine={this.engine}
        size={50}
        node={event.model.cleanUp()}
        setAllAtOncePositions={this.setAllAtOncePositions}
      />
    );
  }

  /**
   * Generates the node model's placeholder
   * @param { GenerateWidgetEvent<T> } event
   * @return { QuestionNodeModel }
  */
  generateModel(event) {
    return new QuestionNodeModel();
  }
}
