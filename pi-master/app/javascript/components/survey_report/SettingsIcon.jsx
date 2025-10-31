import React from 'react';
import PropTypes from 'prop-types';

const SettingsIcon = ({icon, additionalClasses}) => {
  return (
    <span
      className={`settings-icon ${additionalClasses ? additionalClasses : ''}`}
      style={{
        maskImage: `url(${icon})`,
        WebkitMaskImage: `url(${icon})`,
      }}
    >
    </span>
  );
};

SettingsIcon.propTypes = {
  icon: PropTypes.string.isRequired,
  additionalClasses: PropTypes.string,
};

export default SettingsIcon;
