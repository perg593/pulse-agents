import React from 'react';
import PropTypes from 'prop-types';

import PanelTemplate from './PanelTemplate.jsx';

const NamePanel = ({name}) => {
  const id = 'scheduled_report_name_field';

  return (
    <PanelTemplate title='Name'>
      <div className='form-row'>
        <label className='form-label' htmlFor={id}>
          Report Name
        </label>
        <input
          id={id}
          type='text'
          name='scheduled_report[name]'
          defaultValue={name}
          required="required"
        />
      </div>
    </PanelTemplate>
  );
};

NamePanel.propTypes = {
  name: PropTypes.string,
};

export default NamePanel;
