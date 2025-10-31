/**
 * A Pageview Count filter
 */
export class PageviewCountFilter {
  /**
   * @param {string} comparator - How to match (e.g. "greater_than", "less_than")
   * @param {string} value - The value to match
   */
  constructor(comparator, value) {
    this.comparator = comparator;
    this.value = value;
  }
};
