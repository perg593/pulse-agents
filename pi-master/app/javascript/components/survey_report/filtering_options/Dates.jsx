import React from 'react';
import PropTypes from 'prop-types';

import {format} from 'date-fns';

import CollapsiblePanel from '../../CollapsiblePanel';

import DateRangeDatePickerPanel from '../../DateRangeDatePickerPanel';
import 'react-datepicker/dist/react-datepicker.css';

Dates.propTypes = {
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  updateFunction: PropTypes.func.isRequired,
  dateRange: PropTypes.array.isRequired,
};

/**
 * The Dates filtering panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function Dates(props) {
  const summary = () => {
    if (props.dateRange[0] && props.dateRange[1]) {
      const [startDate, endDate] = props.dateRange.map((date) => {
        return format(date, 'MM-dd-yyyy');
      });

      return `${startDate} - ${endDate}`;
    } else {
      return null;
    }
  };

  return (
    <CollapsiblePanel
      panelTitle='Date Range'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      summary={summary()}
      expandByDefault
    >
      <div className='sidebar-option-row'>
        <DateRangeDatePickerPanel
          updateFunction={props.updateFunction}
          dateRange={props.dateRange}
          placement='bottom-end'
        />
      </div>
    </CollapsiblePanel>
  );
}

export default Dates;
