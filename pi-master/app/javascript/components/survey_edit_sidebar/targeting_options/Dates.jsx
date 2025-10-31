import React from 'react';
import PropTypes from 'prop-types';

import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';

import CollapsiblePanel from '../../CollapsiblePanel';

Dates.propTypes = {
  startsAt: PropTypes.instanceOf(Date),
  endsAt: PropTypes.instanceOf(Date),
  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Renders the date trigger panel
 * @param { Dates.propTypes } props
 * @return { JSX.Element } the date trigger panel
 */
function Dates(props) {
  return (
    <CollapsiblePanel
      panelTitle='Dates'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
    >
      <div className='sidebar-option-row'>
        <label
          className='sidebar-label'
          htmlFor='starts_at_field'
        >
          Beginning (UTC):
        </label>
        <DatePicker
          selected={props.startsAt || ''}
          startDate={props.startsAt || ''}
          onChange={(date) => props.updateFunction({startsAt: date || ''})}
          openToDate={props.startsAt || new Date()}
          placeholderText="Start Immediately"
          dateFormat="yyyy-MM-dd hh:mm"
          showTimeSelect
          isClearable={props.startsAt}
          maxDate={props.endsAt}
          minTime={(new Date()).setHours(0, 0)}
          maxTime={props.endsAt && props.endsAt.length != 0 ? props.endsAt : (new Date()).setHours(23, 30)}
        />
      </div>
      <div className='sidebar-option-row'>
        <label
          className='sidebar-label'
          htmlFor='ends_at_field'
        >
          Ending (UTC):
        </label>
        <DatePicker
          selected={props.endsAt || ''}
          startDate={props.endsAt || ''}
          onChange={(date) => {
            const newDate = date || '';

            // We picked an end date and it's the same as the start date
            if (props.startsAt && date && props.startsAt.getDate() === date.getDate()) {
              newDate.setHours(props.startsAt.getHours() + 1);
            }

            return props.updateFunction({endsAt: newDate});
          }}
          openToDate={props.endsAt || new Date()}
          placeholderText="No End Date"
          dateFormat="yyyy-MM-dd hh:mm"
          showTimeSelect
          isClearable={props.endsAt}
          minDate={props.startsAt}
          minTime={props.startsAt && props.startsAt.length != 0 ? props.startsAt : (new Date()).setHours(0, 0)}
          maxTime={(new Date()).setHours(23, 30)}
        />
      </div>
    </CollapsiblePanel>
  );
}

export default Dates;
