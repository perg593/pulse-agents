import {
  updateDateRangeQueryParams,
} from '../CalendarContainer';

export const FILTER_DATE = 'dateRangeFilters';
export const FILTER_DEVICE = 'deviceFilters';
export const FILTER_MARKET = 'marketFilters';
export const FILTER_COMPLETION_URL = 'completionUrlFilters';
export const FILTER_PAGEVIEW_COUNT = 'pageviewCountFilter';
export const FILTER_VISIT_COUNT = 'visitCountFilter';

const ALL_FILTER_KEYS = [
  FILTER_DATE,
  FILTER_DEVICE,
  FILTER_MARKET,
  FILTER_COMPLETION_URL,
  FILTER_PAGEVIEW_COUNT,
  FILTER_VISIT_COUNT,
];

const FILTER_URL_PARAMS = {
  [FILTER_DEVICE]: 'device_types[]',
  [FILTER_MARKET]: 'market_ids[]',
  [FILTER_COMPLETION_URL]: 'completion_urls[]',
  [FILTER_PAGEVIEW_COUNT]: 'pageview_count',
  [FILTER_VISIT_COUNT]: 'visit_count',
};

/**
 * Wraps filters and provides helpers
 * TODO: Consider a more appropriate name
 */
export class FilterGenie {
  /**
   * @param {Object} filters - An object of the form
   *   {selections: {}, initial: {}, defaults: {}}
   * @param {bool} marketFilterAvailable - whether market filters are available
   */
  constructor(filters, marketFilterAvailable) {
    this.selectedFilters = filters.selections;
    this.initialFilterSelection = filters.initial;
    this.defaultFilterSelection = filters.defaults;
    this.marketFilterAvailable = marketFilterAvailable;
  }

  /**
   * Do the two provided arrays have the same content?
   * @param {Array} a an array
   * @param {Array} b another array
   * @return {bool}
   */
  static arraysEqual(a, b) {
    // TODO: argument checking
    if (a.length !== b.length) {
      return false;
    }

    return a.every((aVal) => {
      return b.includes(aVal);
    });
  }

  /**
   * Removes any existing query parameters in filterContext from a URL and
   * replaces them with new values.
   *
   * @param {string} filterContext - The name of the query param
   * @param {array} newValues - The complete set of values for the query param.
   *   May also be a single object or value.
   * @param {URL} url - The url to modify
   * @return {URL} the url with old query parameters of type filterContext
   *   removed and the ones from newValues added
   */
  static updateQueryParams(filterContext, newValues, url) {
    [newValues].flat().forEach((filterValue) => {
      let value = null;

      if (typeof(filterValue) === 'object') {
        if (!!filterValue.value.trim()) {
          value = JSON.stringify(filterValue);
        }
      } else {
        value = filterValue;
      }

      if (value !== null) {
        url.searchParams.append(filterContext, value);
      }
    });

    return url;
  };

  /**
   * TODO: Reconsider this
   * Specifies whether a filter is stored in an array
   * @param {string} filter - the filter to check
   * @return {bool} whether or not the filter is stored in an array
   */
  static filterIsArrayType(filter) {
    return filter !== FILTER_PAGEVIEW_COUNT && filter !== FILTER_VISIT_COUNT;
  }

  /**
   * Determines whether a filter has changed from its initial value
   * @param {string} filter - the filter to check
   * @return {bool} whether or not the filter was changed
   */
  filterChanged(filter) {
    if (!ALL_FILTER_KEYS.includes(filter)) {
      return undefined;
    }

    if (FilterGenie.filterIsArrayType(filter)) {
      return !FilterGenie.arraysEqual(this.selectedFilters[filter],
          this.initialFilterSelection[filter]);
    } else {
      return this.selectedFilters[filter] !== this.initialFilterSelection[filter];
    }
  }

  /**
   * Determines whether the filter matches its default values
   * @param {string} filter - the filter to check
   * @return {bool} whether the current filters are different
   */
  filterMatchesDefault(filter) {
    if (!ALL_FILTER_KEYS.includes(filter)) {
      return undefined;
    }

    if (FilterGenie.filterIsArrayType(filter)) {
      return FilterGenie.arraysEqual(this.selectedFilters[filter],
          this.defaultFilterSelection[filter]);
    } else {
      return this.selectedFilters[filter] === this.defaultFilterSelection[filter];
    }
  }

  /**
   * Is the current selection valid?
   * @param {string} filter - the filter to check
   * @return {bool} whether the current selection is valid
   */
  filterValid(filter) {
    if (filter === FILTER_COMPLETION_URL) {
      return true;
    }

    if (filter === FILTER_PAGEVIEW_COUNT || filter === FILTER_VISIT_COUNT) {
      return true;
    }

    if ([FILTER_DEVICE, FILTER_MARKET].includes(filter)) {
      return this.selectedFilters[filter].length !== 0;
    } else {
      return undefined;
    }
  }

  /**
   * Determines whether the filters have been changed meaningfully
   * @return {bool} whether the filters are different
   */
  anyFiltersApplied() {
    return ALL_FILTER_KEYS.some((filter) => {
      return this.filterChanged(filter);
    });
  };

  /**
   * Generates a url with query params for all applied filters
   * @return {URL} a url with query parameters for all applied filters
   */
  generateQueryParams() {
    let url = new URL(window.location);

    const filters = [
      FILTER_DEVICE, FILTER_COMPLETION_URL, FILTER_PAGEVIEW_COUNT,
      FILTER_VISIT_COUNT,
    ];

    if (this.marketFilterAvailable) {
      filters.push(FILTER_MARKET);
    }

    filters.forEach((filter) => {
      url.searchParams.delete(FILTER_URL_PARAMS[filter]);

      if (!this.filterMatchesDefault(filter)) {
        url = FilterGenie.updateQueryParams(
            FILTER_URL_PARAMS[filter],
            this.selectedFilters[filter],
            url,
        );
      }
    });

    url = updateDateRangeQueryParams(
        ...this.selectedFilters.dateRangeFilters, url,
    );

    return url;
  }

  /**
   * @return {bool} whether all applicable filter selections are valid
   */
  allValid() {
    return this.filterValid(FILTER_DEVICE) &&
      (!this.marketFilterAvailable || this.filterValid(FILTER_MARKET)) &&
      this.filterValid(FILTER_COMPLETION_URL) &&
      this.filterValid(FILTER_PAGEVIEW_COUNT) &&
      this.filterValid(FILTER_VISIT_COUNT);
  }
};
