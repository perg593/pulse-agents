import * as React from 'react';

import {DiagramEngine, PortWidget} from '@projectstorm/react-diagrams';

import {ResizableBox} from 'react-resizable';
import 'react-resizable/css/styles.css';

import {InvitationNodeModel} from './InvitationNodeModel';
import {EditableField} from '../survey_editor/EditableField';

import DeleteIcon from '../../images/survey_editor/delete.svg';

import InvitationSettingsModal from '../survey_editor/InvitationSettingsModal';

export interface InvitationNodeWidgetProps {
  node: InvitationNodeModel;
  engine: DiagramEngine;
  size?: number;
}

/**
 * The React widget representing an Invitation (aka Invitation Card)
 */
export class InvitationNodeWidget
  extends React.Component<InvitationNodeWidgetProps> {
  /**
   * Initializes the InvitationNodeWidget
   * @param { Object } props - contains node model data and an engine reference
   */
  constructor(props) {
    super(props);

    this.nodeContext = 'survey';
    this.linkColor = '#9B62A7';

    this.props.node.getStartPort().setActiveColor(this.linkColor);
    this.readOnly = this.props.engine.getModel().readOnly;
  }

  /**
   * Flags the node as deleted and repaints.
   * Does not actually delete the node.
   */
  deleteInvitation() {
    this.props.node.delete();
    this.props.engine.repaintCanvas();
  }

  /**
   * Renders the footer that appears on node selection
   * @return { JSX.Element } The footer
   */
  renderFooter(): JSX.Element {
    return (
      <div className='node-footer'>
        {
          this.readOnly ? null : <>
            <a onClick={() => this.deleteInvitation()} href='#'>
              <img src={DeleteIcon}/>
              <span>DELETE</span>
            </a>

            <InvitationSettingsModal
              engine={this.props.engine}
              node={this.props.node}
            />
          </>
        }
      </div>
    );
  }

  /**
   * Renders hidden form inputs
   * This is where we render fields that were set in modals
   * @return { JSX.Element } All necessary hidden inputs
  */
  renderHiddenInputs() {
    let nodeProperties = [
      {
        name: 'invitation_button_disabled',
        value: this.props.node.invitation.invitationButtonDisabled,
      },
    ];

    if (this.props.node.deleted) {
      nodeProperties = [
        {
          name: 'invitation',
          value: '',
        },
      ];
    }

    return (
      nodeProperties.map((nodeProperty) => {
        if (Array.isArray(nodeProperty.value)) {
          const fields = [];
          for (let i = 0; i < nodeProperty.value.length; i++) {
            fields.push(
                <input
                  name={`${this.nodeContext}[${nodeProperty.name}][]`}
                  type='hidden'
                  value={nodeProperty.value[i]}
                  key={`${nodeProperty.name}_${i}`}
                />,
            );
          }

          return fields;
        } else {
          return (
            <input
              name={`${this.nodeContext}[${nodeProperty.name}]`}
              type='hidden'
              value={nodeProperty.value}
              key={nodeProperty.name}
            />
          );
        }
      })
    );
  }

  /**
   * Renders the InvitationNodeWidget
   * @return { InvitationNodeWidget }
   */
  render() {
    const node = this.props.node;
    const isSelected = node.isSelected();
    const startPort = this.props.node.getStartPort();

    Object.values(startPort.links).forEach((link) => {
      link.setActiveColor(this.linkColor);
      link.setUseActiveColor(isSelected);

      // The only time there is no target port is when we're
      // retargeting the link
      if (link.targetPort) {
        link.targetPort.setActiveColor(this.linkColor);
      }
    });

    if (this.props.node.deleted) {
      return (
        <div
          className={
            `node-contents ${ isSelected ? ' selected' : '' } start-node`
          }
        >
          <div className='node-body'>
            <h2 className='node-type-label'>SURVEY BEGINS</h2>
          </div>

          <PortWidget
            style={{ backgroundColor: startPort.currentColor() }}
            port={startPort}
            engine={this.props.engine}
            className={`question-port out ${node.hidePorts ? 'hidden' : null}`}
          />
          <input
            name={`${this.nodeContext}[invitation_diagram_properties_attributes][id]`}
            type='hidden'
            value={node.persistentDiagramProperties.id}
          />

          { this.renderHiddenInputs(node) }
        </div>
      );
    } else {
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
            className={
              `node-contents invitation-node${ isSelected ? ' selected' : '' }`
            }
          >
            <div className='node-body'>
              <h2 className='node-type-label'>INVITATION TEXT</h2>

              <EditableField
                placeholderTagName='h1'
                placeholderTagClass='node-header-label'
                placeholderText={'enter invitation text'}
                initialContent={node.invitation.invitation}
                inputContext={`${this.nodeContext}[invitation]`}
                inputClass='node-header-input'
                node={node}
              />

              <label className='node-bubble-container-header'>Button Text</label>

              <div className='node-bubble-container'>
                <EditableField
                  placeholderTagName='span'
                  placeholderTagClass='node-bubble-placeholder'
                  placeholderText={'enter invitation button text'}
                  initialContent={node.invitation.invitationButton}
                  inputContext={`${this.nodeContext}[invitation_button]`}
                  inputClass='node-bubble-input'
                  node={node}
                />
              </div>

              { this.renderHiddenInputs(node) }
            </div>
            { isSelected ? this.renderFooter() : null }

            <input
              name={`${this.nodeContext}[invitation_diagram_properties_attributes][id]`}
              type='hidden'
              value={this.props.node.persistentDiagramProperties.id}
            />

            <PortWidget
              style={{ backgroundColor: startPort.currentColor() }}
              port={startPort}
              engine={this.props.engine}
              className={`question-port out ${node.hidePorts ? 'hidden' : null}`}
            />
          </div>
        </ResizableBox>
      );
    }
  }
}
