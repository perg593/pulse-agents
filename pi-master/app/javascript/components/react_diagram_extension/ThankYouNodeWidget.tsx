import * as React from 'react';

import {DiagramEngine} from '@projectstorm/react-diagrams';

import {ResizableBox} from 'react-resizable';
import 'react-resizable/css/styles.css';

import {ThankYouNodeModel} from './ThankYouNodeModel';

import {EditableField} from '../survey_editor/EditableField';

export interface ThankYouNodeWidgetProps {
  node: ThankYouNodeModel;
  engine: DiagramEngine;
  size?: number;
}

/**
 * The React widget representing a ThankYouNode (aka Thank You Card)
 */
export class ThankYouNodeWidget
  extends React.Component<ThankYouNodeWidgetProps> {
  /**
   * Initializes the ThankYouNodeWidget
   * @param { Object } props - contains node model data and an engine reference
   */
  constructor(props) {
    super(props);

    this.nodeContext = 'survey';

    this.updatePollEnabled = this.updatePollEnabled.bind(this);
  }

  /**
   * Updates our the node's pollEnabled data
   * @param { boolean } newValue - whether or not to enable the poll
   */
  updatePollEnabled(newValue: boolean) {
    this.props.node.updateThankYou({pollEnabled: newValue});
    // TODO: This feels unnecessary, but the widget isn't
    // recognizing the model change
    this.props.engine.repaintCanvas();
  }

  /**
   * Renders hidden form inputs
   * @return { JSX.Element } All necessary hidden inputs
   */
  renderHiddenInputs(): JSX.Element {
    return (
      <>
        <input
          name={`${this.nodeContext}[thank_you_diagram_properties_attributes][id]`}
          type='hidden'
          value={this.props.node.persistentDiagramProperties.id}
        />
        {
          !this.props.node.thankYou.pollEnabled ?
            <input
              name={`${this.nodeContext}[poll_enabled]`}
              type='hidden'
              value='false'
            /> :
              null
        }
      </>
    );
  }

  /**
   * Renders the ThankYouNodeWidget
   * @return { ThankYouNodeWidget }
   */
  render(): JSX.Element {
    const node = this.props.node;
    const isSelected = node.isSelected();

    return (
      <ResizableBox width={385} height={200}
        minConstraints={[385, 200]} maxConstraints={[1000, 1000]}
        className='box'
        resizeHandles={['ne']}
        axis='x'
        onResize={() => this.props.node.setLocked(true)}
        onResizeStop={() => this.props.node.setLocked(false)}
      >
        <div
          className={`node-contents thank-you-node${ isSelected ? ' selected' : '' }`}
        >
          <div className='node-body'>
            <h2 className='node-type-label'>THANK YOU</h2>

            <EditableField
              placeholderTagName='h1'
              placeholderTagClass='node-header-label'
              placeholderText={'enter thank you text'}
              initialContent={node.thankYou.thankYou || ''}
              inputContext={`${this.nodeContext}[thank_you]`}
              inputClass='node-header-input'
              node={node}
            />

            <div className='node-option-row'>
              <input
                type='checkbox'
                id='poll_enabled'
                name={`${this.nodeContext}[poll_enabled]`}
                defaultChecked={node.thankYou.pollEnabled}
                onChange={(e) => this.updatePollEnabled(e.target.checked)}
                value={node.thankYou.pollEnabled || false} // TODO: Add
                // not_null requirement to this boolean field
              />

              <label
                htmlFor='poll_enabled'
                className='node-option-label'
              >
                Show results instead
              </label>
            </div>

            { this.renderHiddenInputs() }
          </div>
        </div>
      </ResizableBox>
    );
  }
}
