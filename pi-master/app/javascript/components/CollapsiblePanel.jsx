import React from 'react';
import PropTypes from 'prop-types';
import classNames from 'classnames';

import ToggleHeader from './ToggleHeader';
import DisabledFeaturesContext from './survey_editor/DisabledFeaturesContext';

CollapsiblePanel.propTypes = {
  panelTitle: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired,
  panelExpansionSettings: PropTypes.object,
  updatePanelExpansionSettings: PropTypes.func,
  summary: PropTypes.string,
  additionalHeaderClasses: PropTypes.string,
  panelClass: PropTypes.string,
  expandByDefault: PropTypes.bool,
};

/**
 * A collapsible panel
 * @param { Object } props (see above)
 * @return { JSX.Element } the panel
 */
function CollapsiblePanel(props) {
  const [localExpanded, setLocalExpanded] = React.useState(true);

  const propDriven = props.panelExpansionSettings !== undefined;

  /**
   * Get the expanded state of the panel
   * @return { boolean } the expanded state
   **/
  function isExpanded() {
    if (propDriven) {
      return props.panelExpansionSettings[props.panelTitle] ?? props.expandByDefault ?? false;
    } else {
      return localExpanded;
    }
  }

  /**
   * Set the expanded state of the panel
   * @param { boolean } newValue the new value
   **/
  function setIsExpanded(newValue) {
    if (propDriven) {
      const newSetting = {};
      newSetting[props.panelTitle] = newValue;
      props.updatePanelExpansionSettings(newSetting);
    } else {
      setLocalExpanded(newValue);
    }
  }

  return (
    <div className='collapsible-panel'>
      <ToggleHeader
        title={props.panelTitle}
        expanded={isExpanded()}
        toggleFunction={setIsExpanded}
        summary={props.summary}
        additionalClasses={props.additionalHeaderClasses}
      />

      {
        isExpanded() ?
          <fieldset
            className={classNames('collapsible-panel-content', props.panelClass)}
            disabled={React.useContext(DisabledFeaturesContext).readOnly}
          >
            { props.children }
          </fieldset> :
          null
      }
    </div>
  );
}

export default CollapsiblePanel;
