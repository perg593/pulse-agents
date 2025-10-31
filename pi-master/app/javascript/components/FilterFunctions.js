import {matchSorter} from 'match-sorter';

/**
 * Filters surveys and survey locale groups by date
 * The top-level survey locale group will match if at least one of its surveys
 * matches.
 *
 * @param {array} rows - the react-table rows to filter
 * @param {number} id - the id of the column to filter on
 * @param {object} filterValue - Array<Date>[startDate, endDate]> or
 *   Date (startDate)
 *
 * @return {array} - an array of matching rows
 */
function customDateFiltering(rows, id, filterValue) {
  return rows.filter((row) => {
    let startDate;
    let endDate;

    if (Array.isArray(filterValue)) {
      startDate = filterValue[0];
      endDate = filterValue[1];
    } else {
      startDate = filterValue;

      endDate = new Date(startDate);
      endDate = new Date(endDate.setHours(24));
    }

    const numSubrows = row.subRows.length;
    for (let i = 0; i < numSubrows; i++) {
      const rowValue = row.subRows[i].values[id];

      if (rowValue) {
        const tableDate = new Date(rowValue);

        if (tableDate >= startDate && tableDate < endDate) {
          return true;
        }
      }
    }

    const rowValue = row.values[id];

    if (rowValue) {
      const tableDate = new Date(rowValue);

      return tableDate >= startDate && tableDate < endDate;
    } else {
      return false;
    }
  });
}

/**
 * If input is an array, returns input
 * If input is not an array, returns an array containing input
 * @param { object } input - an array or a non-array value
 *
 * @return { Array }
 */
function arrayWrap(input) {
  return Array.isArray(input) ? input : [input];
}

/**
 * Returns all rows matching any one of the specified filterValues
 *
 * @param {array} rows - the react-table rows to filter
 * @param {number} id - the id of the column to filter on
 * @param {array} filterValues - Array<string>
 *
 * @return {array} - an array of matching rows
 */
function customORFiltering(rows, id, filterValues) {
  return rows.filter((row) => {
    const rowValues = arrayWrap(row.values[id]);

    if (filterValues.find((filterValue) => {
      return rowValues.includes(filterValue);
    })) {
      return true;
    }

    const numSubrows = row.subRows.length;
    for (let i = 0; i < numSubrows; i++) {
      const subRowValues = arrayWrap(row.subRows[i].values[id]);

      if (filterValues.find((filterValue) => {
        return subRowValues.includes(filterValue);
      })) {
        return true;
      }
    }

    return false;
  });
}

/**
 * Uses matchSorter to perform fuzzy text filtering on multiple columns
 *
 * @param {array} rows - the react-table rows to filter
 * @param {number} _id - the id of the column to
 *   filter on (unused, we define our own filter columns)
 * @param {string} filterValue - the text to filter on
 *
 * @return {array} - an array of matching rows
 */
function fuzzyTextFilter(rows, _id, filterValue) {
  // TODO: check depth and make appropriate check. leaves don't have subrows.
  return matchSorter(rows, filterValue, {
    keys: [
      (item) => item.values['nameID'],
      (item) => item.subRows.map((i) => i.values['nameID']),
      (item) => item.values['searchableContentID'],
      (item) => item.subRows.map((i) => i.values['searchableContentID']),
      // Semi-precise filtering for db record IDs
      // Unfortunately, this threshold value returns
      // inaccurate results for some groups:
      // threshold: matchSorter.rankings.EQUAL
      // https://github.com/kentcdodds/match-sorter/issues/126
      {key: (item) => item.values['possibleAnswerIdsID'], threshold: matchSorter.rankings.EQUAL},
      {key: (item) => item.subRows.map((i) => i.values['possibleAnswerIdsID'])},
      {key: (item) => item.values['surveyID']},
      {key: (item) => item.subRows.map((i) => i.values['surveyID'])},
      {key: (item) => item.values['surveyLocaleGroupID'], threshold: matchSorter.rankings.EQUAL},
      {key: (item) => item.subRows.map((i) => i.values['surveyLocaleGroupID'])},
    ],
  });
}

export { customDateFiltering, customORFiltering, fuzzyTextFilter, arrayWrap };
