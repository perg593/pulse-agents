/**
 * A Visit Count filter
 */
export class VisitCountFilter {
  /**
   * @param {string} comparator - How to match (e.g. "greater_than", "equal_to")
   * @param {string} value - The value to match
   */
  constructor(comparator, value) {
    this.comparator = comparator;
    this.value = value;
  }
}
