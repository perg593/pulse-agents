/**
 * A Completion Url filter
 */
export class CompletionUrlFilter {
  /**
   * @param {number} id - Used to distinguish this filter from other
   *   CompletionUrlFilters
   * @param {string} matcher - How to match (e.g. "contains", "regex")
   * @param {string} value - The value to match
   * @param {bool} cumulative - Whether to AND with other CompletionUrlFilters
   */
  constructor(id, matcher, value, cumulative) {
    this.id = id;
    this.matcher = matcher;
    this.value = value;
    this.cumulative = cumulative;
  }
};
