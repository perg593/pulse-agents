import React from 'react';
import PropTypes from 'prop-types';

/**
 * A fancy radio button
 **/
class RadioControl extends React.Component {
  /**
   * Initialize RadioControl
   * @param {Object} props - see PropTypes
   **/
  constructor(props) {
    super(props);
  }

  /**
   * Renders the RadioControl
   * @return {JSX.Element}
  **/
  render() {
    return (
      <>
        <input
          type="radio"
          id={this.props.id}
          value={this.props.value}
          onChange={(e) => {
            this.props.onChange(e);
          }}
          defaultChecked={this.props.selected}
          name={this.props.groupName}
        />
        <label
          className='settings-control'
          htmlFor={this.props.id}
        >
          {this.props.label}
          {this.props.children}
        </label>
      </>
    );
  }
}

RadioControl.propTypes = {
  id: PropTypes.string.isRequired,
  value: PropTypes.string.isRequired,
  onChange: PropTypes.func.isRequired,
  selected: PropTypes.bool.isRequired,
  label: PropTypes.string,
  groupName: PropTypes.string.isRequired,
  children: PropTypes.node,
};

export default RadioControl;
