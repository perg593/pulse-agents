import React from 'react';
import PropTypes from 'prop-types';

SidebarTab.propTypes = {
  tabName: PropTypes.string.isRequired,
  tabLabel: PropTypes.string.isRequired,
  openTabName: PropTypes.string.isRequired,
  onTabClick: PropTypes.func.isRequired,
};

/**
 * A top-level tab in a sidebar
 *
 * @param { Object } props
 * @return { SidebarTab }
 */
function SidebarTab(props) {
  return (
    <li
      className={`${props.openTabName === props.tabName ? 'selected' : ''}`}
      onClick={() => props.onTabClick(props.tabName)}
    >
      {props.tabLabel}
    </li>
  );
}

export default SidebarTab;
