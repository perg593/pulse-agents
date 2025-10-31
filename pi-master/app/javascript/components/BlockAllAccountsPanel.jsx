import React from 'react';
import PropTypes from 'prop-types';

import PanelTemplate from './scheduled_reports/PanelTemplate.jsx';

BlockAllAccountsPanel.propTypes = {
  authenticityToken: PropTypes.string.isRequired,
  qrveyEnabled: PropTypes.bool.isRequired,
};

/**
 * TODO:
 * - Style button
 * - Style checkbox
 * - Style label
 * - Style container
 * @param {Object} props -- see propTypes above
 * @return { JSX.Element }
 **/
function BlockAllAccountsPanel(props) {
  return (
    <PanelTemplate title='Block all accounts from Qrvey'>
      <form
        action='update_all_qrvey_access'
        method='POST'
      >
        <div className='settings-row'>
          <div className='settings-container'>
            <input
              type='hidden'
              name='authenticity_token'
              value={props.authenticityToken}
            />
            <input type='hidden' name='_method' value='patch' />

            <label htmlFor='block_all'>
              Block all
            </label>
            <input
              id='block_all'
              type='checkbox'
              name='block_all'
              value='true'
              defaultChecked={props.qrveyEnabled}
            />
          </div>

          <div className='button-container'>
            <button
              className='pi-primary-button'
              type='submit'
            >
              Update
            </button>
          </div>
        </div>
      </form>
    </PanelTemplate>
  );
};

export default BlockAllAccountsPanel;
