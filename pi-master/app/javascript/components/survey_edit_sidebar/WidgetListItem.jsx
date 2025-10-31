import React from 'react';
import PropTypes from 'prop-types';

WidgetListItem.propTypes = {
  widget: PropTypes.object.isRequired,
  value: PropTypes.string.isRequired,
};

/**
 * An individual list item for widget positioning
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function WidgetListItem({widget, value}) {
  const checked = widget.checked ? widget.checked() :
    value === widget.value;

  return (
    <li>
      <label htmlFor={widget.value}>
        <img src={widget.icon} />
        {widget.label}
      </label>

      <input
        type="radio"
        id={widget.value}
        value={widget.value}
        onChange={widget.onChange}
        checked={checked}
        name={widget.name}
      />
    </li>
  );
}

export default WidgetListItem;
