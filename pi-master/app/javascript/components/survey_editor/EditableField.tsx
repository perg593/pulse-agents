import React from 'react';

import OutsideClickHandler from 'react-outside-click-handler';

export interface EditableFieldProps {
  initialContent: string;
  inputContext: string;
  node: DefaultNodeModel;
  placeholderTagName: string;
  placeholderText: string;
  inputClass: string;
  contentToDisplay: string;
  readOnly: boolean;
}

/**
 * An editable text field with two modes: read and edit.
 * Shows a placeholder tag in read mode.
 * Shows an input field in edit mode.
 * Toggles between modes based on clicks and key presses.
*/
export class EditableField extends React.Component<EditableFieldProps> {
  state: Object;

  /**
   * Initializes the EditableField
   * @param { EditableFieldProps } props
  */
  constructor(props) {
    super(props);

    this.state = {
      content: props.initialContent,
      editing: false,
      beganEdit: false,
    };

    this.setContent = this.setContent.bind(this);
    this.setEditing = this.setEditing.bind(this);
    this.onKeyDown = this.onKeyDown.bind(this);
  }

  /**
   * Sets the field's content
   * @param { string } newValue - the new field content
  */
  setContent(newValue: string) {
    this.setState({
      content: newValue,
    });
  }

  /**
   * Sets whether field is in editing mode
   * @param { bool } newState - true if editing
  */
  setEditing(newState: boolean) {
    if (this.props.node) {
      this.props.node.setLocked(newState);
    }

    if (!newState && this.props.onUpdate) {
      this.props.onUpdate(this.state.content);
    }

    this.setState(
        {
          beganEdit: newState && !this.state.editing,
          editing: newState,
        },
    );
  }

  /**
   * Runs when component has updated.
  */
  componentDidUpdate() {
    if (this.state.beganEdit) {
      this.refs.inputField.focus();
    }
  }

  /**
   * onKeyDown handler
   * @param { Object } e - the keyDown event
  */
  onKeyDown(e) {
    if (e.key === 'Escape') {
      this.setEditing(false);
    }
  }

  /**
   * Renders the input field
   * @return {JSX.Element}
  */
  renderInputField() {
    return (
      <input
        ref="inputField"
        name={this.props.inputContext}
        value={this.state.content}
        onKeyDown={this.onKeyDown}
        onChange={(e) => this.setContent(e.target.value)}
        placeholder={this.props.placeholderText}
        className={this.props.inputClass}
      />
    );
  }

  /**
   * Determine what to show in the placeholder tag
   * @return {string} the content to render in non-edit mode
  */
  contentToDisplay() {
    return this.props.contentToDisplay || this.state.content ||
      this.props.placeholderText;
  }

  /**
   * Renders the EditableField
   * @return { JSX.Element } - the EditableField
  */
  render() {
    const PlaceholderTag = this.props.placeholderTagName;

    return (
      <>
        <div
          className='obligatory-wrapper'
          style={{display: this.state.editing ? 'block' : 'none'}}
        >
          {
            this.state.editing ?
              <OutsideClickHandler onOutsideClick={() => this.setEditing(false)}>
                { this.renderInputField() }
              </OutsideClickHandler> :
                this.renderInputField()
          }
        </div>

        <PlaceholderTag
          className={this.props.placeholderTagClass}
          onDoubleClick={() => {
            if (!this.props.readOnly) {
              this.setEditing(true);
            }
          }}
          style={{display: this.state.editing ? 'none' : 'block'}}
        >
          { this.contentToDisplay() }
        </PlaceholderTag>
      </>
    );
  }
}
