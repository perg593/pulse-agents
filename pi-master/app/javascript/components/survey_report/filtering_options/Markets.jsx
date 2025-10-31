import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../../CollapsiblePanel';

import InvalidSelectionWarning from './InvalidSelectionWarning';

Markets.propTypes = {
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  marketFilters: PropTypes.array.isRequired,
  updateFunction: PropTypes.func.isRequired,
  availableMarkets: PropTypes.array.isRequired,
  valid: PropTypes.bool.isRequired,
  invalidHeaderMessage: PropTypes.string.isRequired,
};

/**
 * The Markets filtering panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function Markets(props) {
  const toggleMarketFilter = (market) => {
    const urlFilters = [...props.marketFilters];
    const index = urlFilters.indexOf(market);

    if (index == -1) {
      urlFilters.push(market);
    } else {
      urlFilters.splice(index, 1);
    }

    props.updateFunction(urlFilters);
  };

  const isActive = (market) => {
    return props.marketFilters.includes(market);
  };

  /**
   * Select all market filters
   */
  function selectAll() {
    const allIds = Object.values(props.availableMarkets).map((filter) => {
      return filter.id;
    });

    props.updateFunction(allIds);
  }

  /**
   * Deselect all market filters
   */
  function deselectAll() {
    props.updateFunction([]);
  }

  return (
    <CollapsiblePanel
      summary={`${props.marketFilters.length || props.invalidHeaderMessage}`}
      panelTitle='Markets'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
      additionalHeaderClasses={props.valid ? null : 'invalid-selection'}
    >
      <InvalidSelectionWarning
        valid={props.valid}
        message="Please select at least one market"
      />
      {
        props.availableMarkets.map((market) => {
          return (
            <div className='sidebar-option-row horizontal' key={market.id}>
              <input
                type="checkbox"
                id={`market_filter_${market.id}`}
                onChange={() => toggleMarketFilter(market.id)}
                value={market.id}
                checked={isActive(market.id)}
              />
              <label
                className='sidebar-label'
                htmlFor={`market_filter_${market.id}`}
              >
                { market.label }
              </label>
            </div>
          );
        })
      }
      <div className='sidebar-option-row horizontal' key='select_all'>
        <button href="#" onClick={selectAll}>Select all</button>
        <button href="#" onClick={deselectAll}>Deselect all</button>
      </div>
    </CollapsiblePanel>
  );
}

export default Markets;
