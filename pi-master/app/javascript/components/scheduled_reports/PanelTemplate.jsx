import React from 'react';
import PropTypes from 'prop-types';

const PanelTemplate = (props) => {
  return (
    <div className='panel panel-default'>
      <div className='panel-heading'>
        <h4 className='panel-title'>
          {props.title}
        </h4>
      </div>
      <div className='panel-body'>
        {props.children}
      </div>
    </div>
  );
};

PanelTemplate.propTypes = {
  title: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired,
};

export default PanelTemplate;
