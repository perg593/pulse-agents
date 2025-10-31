import React from 'react';
import PropTypes from 'prop-types';
import classNames from 'classnames';

import ArrowUp from '../images/survey_dashboard/arrow_up.svg';
import ArrowDown from '../images/survey_dashboard/arrow_down.svg';

ToggleHeader.propTypes = {
  title: PropTypes.string.isRequired,
  expanded: PropTypes.bool.isRequired,
  toggleFunction: PropTypes.func.isRequired,
  summary: PropTypes.string,
  additionalClasses: PropTypes.string,
};

/**
 * A header for toggling modal panel visibility
 * @param { Object } props
 * @return { JSX.Element } the header panel
*/
function ToggleHeader(props) {
  return (
    <PanelContainer
      expanded={props.expanded}
      toggleFunction={props.toggleFunction}
      additionalClasses={props.additionalClasses}
    >
      <PanelTitle
        title={props.title}
        expanded={props.expanded}
        summary={props.summary}
      />
      <ToggleIcon expanded={props.expanded} />
    </PanelContainer>
  );
}

PanelContainer.propTypes = {
  expanded: PropTypes.bool.isRequired,
  toggleFunction: PropTypes.func.isRequired,
  additionalClasses: PropTypes.string,
  children: PropTypes.node.isRequired,
};

/**
 * A container for the panel header
 * @param { Object } props
 * @return { JSX.Element } the panel container
 **/
function PanelContainer(props) {
  return (
    <div
      className={
        classNames(
            'collapsible-panel-toggle-header',
            props.expanded ? 'expanded' : 'collapsed',
            props.additionalClasses,
        )
      }
      onClick={() => props.toggleFunction(!props.expanded)}
    >
      {props.children}
    </div>
  );
}

PanelTitle.propTypes = {
  title: PropTypes.string.isRequired,
  expanded: PropTypes.bool.isRequired,
  summary: PropTypes.string,
};

/**
 * A title for the panel
 * @param { Object } props
 * @return { JSX.Element } the title
 **/
function PanelTitle(props) {
  return (
    <h2 className='collapsible-panel-title'>
      {props.title}
      {props.expanded ? null : <span>{ props.summary }</span>}
    </h2>
  );
}

ToggleIcon.propTypes = {
  expanded: PropTypes.bool.isRequired,
};

/**
 * A toggle icon for the panel
 * @param { Object } props
 * @return { JSX.Element } the toggle
 **/
function ToggleIcon(props) {
  return (
    <img
      className='collapsible-panel-toggle'
      src={ props.expanded ? ArrowUp : ArrowDown }
    />
  );
}

export default ToggleHeader;
