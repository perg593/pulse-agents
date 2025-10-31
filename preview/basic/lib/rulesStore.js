// I'm adding a comment to the file to test the commit

export class RulesStore {
  static #instance;

  static shared() {
    if (!this.#instance) {
      this.#instance = new RulesStore();
    }
    return this.#instance;
  }

  #rules = [];

  replaceWith(arr = []) {
    this.#rules = Array.isArray(arr) ? arr.slice() : [];
  }

  all() {
    return this.#rules.slice();
  }

  static fromIngestion(rows = []) {
    const out = [];
    for (const row of rows) {
      const when = row.when || row.rule || '';
      const action = row.action || row.do || 'present';
      const arg = row.arg || row.survey_id || row.id;
      if (when && action === 'present' && arg) {
        out.push({ when, do: 'present', arg });
      }
    }
    return out;
  }
}
