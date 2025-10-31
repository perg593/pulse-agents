import {DiagramEngine, PortModel} from '@projectstorm/react-diagrams';
import {AbstractModelFactory} from '@projectstorm/react-canvas-core';

/**
 * The factory that combines QuestionPorts with their widgets
 */
export class SimplePortFactory
  extends AbstractModelFactory<PortModel, DiagramEngine> {
  cb: (initialConfig?: any) => PortModel;

  /**
   * Initializes the SimplePortFactory
   * @param { string } type - Our own custom name for this type of port
   * @param { Object } cb - not sure where this is specified
   */
  constructor(type: string, cb: (initialConfig?: any) => PortModel) {
    super(type);
    this.cb = cb;
  }

  /**
   * Generates the node model's placeholder
   * @param { GenerateWidgetEvent<T> } event
   * @return { QuestionPortModel }
  */
  generateModel(event): PortModel {
    return this.cb(event.initialConfig);
  }
}
