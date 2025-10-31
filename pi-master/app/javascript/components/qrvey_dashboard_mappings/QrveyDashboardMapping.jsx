import React from 'react';
import PropTypes from 'prop-types';

import EditableField from './EditableField';

QrveyDashboardMapping.propTypes = {
  id: PropTypes.number.isRequired,
  qrveyName: PropTypes.string.isRequired,
  piName: PropTypes.string.isRequired,

  deleteDashboardMapping: PropTypes.func.isRequired,
  updateDashboardMapping: PropTypes.func.isRequired,
};

/**
 * A component for Qrvey dashboard mapping configuration
 * @param { Object } props -- see PropTypes
 * @return { JSX.Element }
*/
function QrveyDashboardMapping(props) {
  /**
   * Ask our parent to update the dashboard mapping record
   *
   * @param { string } attribute - the name of the attribute to update
   * @param { any } value - the new value
   **/
  function updateDashboardMapping(attribute, value) {
    const newVals = {};
    newVals[attribute] = value;

    props.updateDashboardMapping(props.id, newVals);
  };

  return (
    <>
      <td>
        <EditableField
          initialValue={props.qrveyName}
          persistentUpdate={(newValue) => updateDashboardMapping('qrvey_name', newValue) }
        />
      </td>
      <td>
        <EditableField
          initialValue={props.piName}
          persistentUpdate={(newValue) => updateDashboardMapping('pi_name', newValue) }
        />
      </td>
      <td>
        <button onClick={() => props.deleteDashboardMapping(props.id)}>
          DELETE
        </button>
      </td>
    </>
  );
}

export default QrveyDashboardMapping;
