# Local development

## Steps to set up the application
1. Start a client with `psql postgres` and create a role with `CREATE USER pi SUPERUSER;`
2. Run `bin/setup`

## Credentials
Get the master keys from https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/wikis/home#master-keys

Then add your credentials with `bin/rails credentials:edit`

## Migrations
Our PostgreSQL cluster employs logical replication, which synchronizes data based on primary keys by default but doesn't handle DDL commands. Consequently, all replicas must execute migration files, meaning they cannot be set to read-only. However, the application's database user on replicas has write privileges stripped in fear of data inconsistency (**TODO**).

These conditions impose two constraints:
- `ALTER TABLE schema_migrations REPLICA IDENTITY FULL;` needs to be executed after every upgrade/restore (This table doesn't have a primary key)
- Write operations such as `CREATE`, `UPDATE`, and `DELETE` cannot be included in migration files
- Tables must be dropped using `CASCADE` to ensure that the respective sequence is dropped simultaneously

## References
- [Getting Started with PostgreSQL on Mac OSX \| Codementor](https://www.codementor.io/@engineerapart/getting-started-with-postgresql-on-mac-osx-are8jcopb)
