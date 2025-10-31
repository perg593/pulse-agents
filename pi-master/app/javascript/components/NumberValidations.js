// Helper functions for use with react-number-format
// https://www.npmjs.com/package/react-number-format

/**
 * Returns true for float values meeting or exceeding a minimum value
 *
 * @param { Object } values - react-number-format values object
 * @param { number} min - the minimum value
 *
 * @return { bool } true if floatValue is undefined or floatValue >= min
*/
function minValidation(values, min) {
  const {floatValue} = values;
  return floatValue === undefined || floatValue >= min;
}

/**
 * Returns true for float values less than or equal to a minimum value
 *
 * @param { Object } values - react-number-format values object
 * @param { number} max - the maximum value
 *
 * @return { bool } true if floatValue is undefined or floatValue <= min
*/
function maxValidation(values, max) {
  const {floatValue} = values;
  return floatValue === undefined || floatValue <= max;
}

export {minValidation, maxValidation};
