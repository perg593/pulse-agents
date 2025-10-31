import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation} from '../NumberValidations';

RadioButtonProperties.propTypes = {
  onQuestionPropertyChange: PropTypes.func.isRequired,
  questionProperties: PropTypes.object.isRequired,
};

/**
 * A panel for radio button specific properties
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function RadioButtonProperties(props) {
  return (
    <>
      <h4>Desktop</h4>
      <div className='options-row'>
        <NumberFormat
          className='number-input'
          value={props.questionProperties.answersPerRowDesktop}
          thousandSeparator={false}
          decimalSeparator={null}
          isAllowed={(values) => {
            return minValidation(values, 1);
          }}
          onBlur={(e) => {
            props.onQuestionPropertyChange({
              answersPerRowDesktop: e.target.value,
            });
          }}
        />
        <span>Per Rows</span>
      </div>
      <h4>Mobile</h4>
      <div className='options-row'>
        <NumberFormat
          className='number-input'
          value={props.questionProperties.answersPerRowMobile}
          thousandSeparator={false}
          decimalSeparator={null}
          isAllowed={(values) => {
            return minValidation(values, 1);
          }}
          onBlur={(e) => {
            props.onQuestionPropertyChange({
              answersPerRowMobile: e.target.value,
            });
          }}
        />
        <span>Per Rows</span>
      </div>
    </>
  );
};

export default RadioButtonProperties;
