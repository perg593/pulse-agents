# Don't-Do-This Log
Keep this short and alive.

- ❌ Rename view columns directly; use `ALTER VIEW ... RENAME COLUMN`.
- ❌ Mix schema and data migrations in one transaction.
- ❌ Merge before running integration tests on analytics tables.
- ❌ Let Codex refactor without Plan approval.