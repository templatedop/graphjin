# GraphJin - Getting Started Guide

This guide will help you build, configure, and run GraphJin.

## Table of Contents
1. [Building GraphJin](#building-graphjin)
2. [Quick Start with New Project](#quick-start-with-new-project)
3. [Manual Configuration](#manual-configuration)
4. [Running GraphJin](#running-graphjin)
5. [Available Commands](#available-commands)
6. [Configuration Reference](#configuration-reference)
7. [Debugging and Development](#debugging-and-development)

---

## Building GraphJin

### Prerequisites
- Go 1.24.0 or later
- PostgreSQL or MySQL database
- Git

### Build the Binary

```bash
# Navigate to the cmd directory
cd cmd

# Build the GraphJin binary
go build -o graphjin .

# Verify the build
./graphjin version
```

### Install Globally (Optional)

```bash
# Install to $GOPATH/bin
cd cmd
go install .

# Now you can run graphjin from anywhere
graphjin version
```

---

## Quick Start with New Project

The easiest way to get started is to use the `new` command which scaffolds a complete project with configuration files.

### Create a New Application

```bash
# Basic usage (PostgreSQL with defaults)
graphjin new myapp

# With custom database URL
graphjin new myapp --db-url postgres://user:pass@localhost:5432/mydb

# With MySQL
graphjin new myapp --db-url mysql://root:password@localhost:3306/mydb
```

This creates a directory structure like:

```
myapp/
├── config/
│   ├── dev.yml          # Development configuration
│   ├── prod.yml         # Production configuration
│   ├── migrations/      # Database migrations
│   └── queries/         # GraphQL queries (allow-list)
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### Run the New Application

```bash
cd myapp

# Run in development mode
graphjin serve --path ./config

# Or specify config explicitly
graphjin serve --path ./config
```

---

## Manual Configuration

If you prefer to configure GraphJin manually:

### 1. Create Configuration Directory

```bash
mkdir -p config/migrations config/queries
```

### 2. Create Configuration File

Create `config/dev.yml` with the following minimum configuration:

```yaml
app_name: "My GraphJin App"
host_port: 0.0.0.0:8080
web_ui: true

# Development mode - allows all queries, introspection enabled
production: false

# Logging
log_level: "info"
log_format: "plain"

# Database connection
database:
  type: postgres              # or mysql
  host: localhost
  port: 5432                  # 3306 for MySQL
  dbname: mydb
  user: postgres
  password: mypassword
  pool_size: 10

# Authentication (set to 'none' for development)
auth:
  type: none

# Security
secret_key: "change-this-to-a-random-secret-key-in-production"

# CORS
cors_allowed_origins: ["*"]

# Tables to exclude from introspection
blocklist:
  - ar_internal_metadata
  - schema_migrations

# Role-based access control
roles:
  - name: anon
    tables:
      - name: users
        query:
          limit: 10
```

### 3. Create Your Database

```bash
# PostgreSQL
createdb mydb

# Or use MySQL
mysql -e "CREATE DATABASE mydb;"
```

### 4. Run Migrations (Optional)

Create a migration file in `config/migrations/001_initial.sql`:

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (email, name) VALUES
  ('user1@example.com', 'User One'),
  ('user2@example.com', 'User Two');
```

---

## Running GraphJin

### Development Mode

```bash
# Run with default config path (./config)
graphjin serve

# Run with custom config path
graphjin serve --path /path/to/config

# The server will start on http://localhost:8080
# Web UI available at http://localhost:8080
# GraphQL API at http://localhost:8080/api/v1/graphql
```

### Production Mode

1. Update `config/prod.yml` with production settings
2. Set environment variables for sensitive data:

```bash
export GJ_DATABASE_PASSWORD="your-secure-password"
export GJ_SECRET_KEY="your-secret-key-min-32-chars"
export GJ_ADMIN_SECRET_KEY="admin-secret-for-hot-deploy"
```

3. Run with production config:

```bash
graphjin serve --path ./config

# GraphJin will automatically use prod.yml if it exists
# and NODE_ENV=production or similar
```

### Using Environment Variables

You can override any configuration value using environment variables with the `GJ_` prefix:

```bash
# Database settings
export GJ_DATABASE_HOST=db.example.com
export GJ_DATABASE_PORT=5432
export GJ_DATABASE_USER=myuser
export GJ_DATABASE_PASSWORD=mypassword
export GJ_DATABASE_DBNAME=mydb

# Application settings
export GJ_HOST_PORT=0.0.0.0:3000
export GJ_LOG_LEVEL=debug

# Auth settings
export GJ_AUTH_TYPE=jwt
export GJ_AUTH_JWT_SECRET=your-jwt-secret
export GJ_AUTH_JWT_PUBLIC_KEY_FILE=/path/to/public.pem

# Run
graphjin serve
```

---

## Available Commands

### `graphjin new <app-name>`
Create a new GraphJin application with scaffolding.

```bash
graphjin new myapp [--db-url postgres://user:pass@host:port/db]
```

### `graphjin serve` (or `serv`)
Start the GraphJin HTTP service.

```bash
graphjin serve [--path ./config] [--deploy-active]

Options:
  --path           Path to config directory (default: ./config)
  --deploy-active  Use the active deployed config
```

### `graphjin db`
Database management commands.

```bash
# Create database
graphjin db create --path ./config

# Test connection
graphjin db status --path ./config
```

### `graphjin migrate`
Run database migrations.

```bash
graphjin migrate --path ./config
```

### `graphjin init`
Initialize admin database for hot-deploy feature.

```bash
graphjin init --path ./config
```

### `graphjin deploy`
Deploy a new configuration (requires hot-deploy enabled).

```bash
graphjin deploy --path ./config
```

### `graphjin version`
Show version information.

```bash
graphjin version
```

---

## Configuration Reference

### Key Configuration Files

The config directory expects this structure:

```
config/
├── dev.yml           # Development config (loaded when NODE_ENV != production)
├── prod.yml          # Production config (inherits from dev.yml)
├── migrations/       # SQL migration files
│   ├── 001_initial.sql
│   └── 002_add_products.sql
└── queries/          # Allow-list queries (production mode)
    ├── get_user.gql
    └── list_products.gql
```

### Config File Naming

GraphJin looks for these files in order:
1. `dev.yml` or `dev.yaml` (development)
2. `prod.yml` or `prod.yaml` (production)
3. `config.yml` or `config.yaml` (fallback)

You can also use TOML or JSON formats.

### Essential Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `app_name` | Application name | - |
| `host_port` | Host and port to listen on | `0.0.0.0:8080` |
| `production` | Production mode (enforces allow-list) | `false` |
| `web_ui` | Enable built-in GraphQL web UI | `true` |
| `log_level` | Logging level: debug, info, warn, error | `info` |
| `log_format` | Log format: json, plain | `plain` |
| `database.type` | Database type: postgres, mysql | `postgres` |
| `database.host` | Database host | `localhost` |
| `database.port` | Database port | `5432` |
| `database.dbname` | Database name | - |
| `database.user` | Database user | - |
| `database.password` | Database password | - |
| `auth.type` | Auth type: none, jwt, header | `none` |
| `secret_key` | Secret for encryption (min 32 chars) | - |
| `cors_allowed_origins` | CORS allowed origins | `["*"]` |
| `default_limit` | Default limit for queries | `20` |

### Role-Based Access Control

Define roles and their permissions:

```yaml
roles:
  # Anonymous users
  - name: anon
    tables:
      - name: products
        query:
          limit: 50
          filters: ["{ published: { eq: true } }"]

  # Authenticated users
  - name: user
    tables:
      - name: products
        query:
          limit: 100

      - name: orders
        query:
          filters: ["{ user_id: { eq: $user_id } }"]

        insert:
          presets:
            - user_id: "$user_id"
            - created_at: "now"

        update:
          filters: ["{ user_id: { eq: $user_id } }"]

        delete:
          block: true  # Prevent deletes

  # Admin users
  - name: admin
    match: id = 1  # Match condition from roles_query
    tables:
      - name: products
        # No restrictions

      - name: users
        # Full access
```

---

## Debugging and Development

### Enable Debug Logging

In `dev.yml`:

```yaml
log_level: "debug"
debug: true
server_timing: true
enable_tracing: true
```

### View Generated SQL

When debug mode is enabled, GraphJin returns the generated SQL in the response:

```json
{
  "data": { ... },
  "sql": "SELECT ... FROM users WHERE ..."
}
```

### Hot Reload

Enable automatic config reload on file changes:

```yaml
reload_on_config_change: true
```

### Web UI

Access the built-in GraphQL explorer at:
```
http://localhost:8080
```

Features:
- GraphQL query editor with syntax highlighting
- Schema explorer
- Query history
- Variable editor

### Database Introspection

GraphJin automatically discovers your database schema. To view the GraphQL schema:

```bash
# Query the introspection endpoint
curl http://localhost:8080/api/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { types { name } } }"}'
```

### Testing Queries

Use curl to test queries:

```bash
# Simple query
curl http://localhost:8080/api/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ users { id email name } }"
  }'

# Query with variables
curl http://localhost:8080/api/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query GetUser($id: Int!) { users(id: $id) { id email name } }",
    "variables": {"id": 1}
  }'
```

### Using Docker

Build and run with Docker:

```bash
# Build image
docker build -t graphjin .

# Run container
docker run -p 8080:8080 \
  -e GJ_DATABASE_HOST=host.docker.internal \
  -e GJ_DATABASE_PASSWORD=mypassword \
  -v $(pwd)/config:/config \
  graphjin serve --path /config
```

Or use Docker Compose (generated by `graphjin new`):

```bash
docker-compose up
```

---

## Common Issues and Solutions

### "Failed to connect to database"

**Solution**: Check your database is running and credentials are correct:

```bash
# PostgreSQL
psql -h localhost -U postgres -d mydb

# MySQL
mysql -h localhost -u root -p mydb
```

### "Config file not found"

**Solution**: Ensure you're in the correct directory or specify `--path`:

```bash
graphjin serve --path /absolute/path/to/config
```

### "Unknown database type"

**Solution**: Set `database.type` to either `postgres` or `mysql`.

### Port Already in Use

**Solution**: Change the port in config:

```yaml
host_port: 0.0.0.0:3000
```

Or use environment variable:

```bash
GJ_HOST_PORT=0.0.0.0:3000 graphjin serve
```

---

## Next Steps

1. **Read the Technical Documentation**: See `TECHNICAL_DOCUMENTATION.md` for architecture details
2. **Explore Example Queries**: Check the GraphQL schema via the web UI
3. **Set Up Authentication**: Configure JWT or other auth methods
4. **Add Migrations**: Create database migrations in `config/migrations/`
5. **Define Allow-List**: Add production queries to `config/queries/`
6. **Configure Roles**: Set up role-based access control for security

---

## Quick Reference

### Minimal Working Example

**config/dev.yml**:
```yaml
app_name: "Quick Start"
host_port: 0.0.0.0:8080
production: false
web_ui: true

database:
  type: postgres
  host: localhost
  port: 5432
  dbname: testdb
  user: postgres
  password: postgres

auth:
  type: none

secret_key: "supercalifragilisticexpialidocious12"
```

**Run**:
```bash
graphjin serve --path ./config
```

**Access**:
- Web UI: http://localhost:8080
- GraphQL API: http://localhost:8080/api/v1/graphql
- REST API: http://localhost:8080/api/v1/rest
- OpenAPI: http://localhost:8080/api/v1/openapi.json
- Health: http://localhost:8080/health

---

## Support and Resources

- **GitHub Repository**: https://github.com/dosco/graphjin
- **Documentation**: See `TECHNICAL_DOCUMENTATION.md` for codebase details
- **Issues**: Report issues on GitHub

Happy coding with GraphJin! 🚀
