if ENV["SCHEMA_MIGRATIONS_TABLE_NAME"]
  ActiveRecord::Base.schema_migrations_table_name = ENV["SCHEMA_MIGRATIONS_TABLE_NAME"]
end