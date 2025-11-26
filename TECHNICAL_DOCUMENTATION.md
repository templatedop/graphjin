# GraphJin Technical Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Package](#core-package)
4. [Serv Package](#serv-package)
5. [Cmd Package](#cmd-package)
6. [Dependencies and Integration](#dependencies-and-integration)
7. [Key Design Patterns](#key-design-patterns)
8. [Production vs Development Modes](#production-vs-development-modes)

---

## Overview

GraphJin is a **GraphQL to SQL compiler** written in Go that automatically converts GraphQL queries into highly efficient SQL queries. It's architected around three main packages that work together to provide both a library (core) and a standalone service (serv).

### Project Structure

```
graphjin/
├── core/           # Core compiler (GraphQL → SQL)
├── serv/           # HTTP service and REST/GraphQL endpoints
├── cmd/            # Command-line interface
├── auth/           # Authentication handlers (JWT, JWKS, Firebase, etc.)
├── plugin/otel/    # OpenTelemetry instrumentation
├── wasm/           # WebAssembly build
├── conf/           # Configuration utilities
└── tests/          # Integration tests
```

---

## Architecture

### Three-Tier Architecture

1. **Core Tier** (`/core`): Pure compiler with minimal dependencies
2. **Service Tier** (`/serv`): HTTP server, configuration management, middleware
3. **CLI Tier** (`/cmd`): Command-line tools using Core and Service

### Compilation Pipeline

```
GraphQL Query
    ↓
[graph.Parse] -------- Parse GraphQL syntax into AST
    ↓
[qcode.Compile] ------ Validate & convert to intermediate representation (QCode)
    ↓
[psql.Compile] ------- Generate optimized SQL from QCode
    ↓
[Execute] ------------ Run SQL and return JSON
```

---

## Core Package

**Location**: `/home/user/graphjin/core`

### Purpose
The core package is a **production-ready GraphQL-to-SQL compiler** that requires only a database connection and schema information. It contains no web framework dependencies, making it embeddable in any Go application.

### Key Files and Their Responsibilities

#### Public API Files

| File | Purpose | Key Functions/Types |
|------|---------|-------------------|
| `api.go` | Main public API | `NewGraphJin()`, `GraphQL()`, `GraphQLByName()`, `Result` type |
| `core.go` | Type definitions and documentation | `graphjinEngine`, `GraphJin`, `Option` pattern |
| `config.go` | Configuration structures | `Config`, `Table`, `Column`, `Role`, `RoleTable` |
| `gstate.go` | Query execution state machine | `gstate`, `cstate`, `compile()`, `compileAndExecute()` |

#### Initialization Files

| File | Purpose | Key Functions |
|------|---------|--------------|
| `init.go` | Configuration initialization | `initConfig()`, `initSchema()`, `initDiscover()`, `initCompilers()` |
| `schema.go` | Database schema management | Schema introspection and discovery |
| `intro.go` | GraphQL introspection | Generates introspection.json for tooling |

#### Feature Files

| File | Purpose |
|------|---------|
| `types.go` | Type mappings and GraphQL schema definitions |
| `crypt.go` | Encryption/decryption for secure cursor values |
| `remote_api.go`, `remote_join.go` | Remote API joins |
| `subs.go` | Subscription support |
| `openapi.go` | OpenAPI/Swagger generation |
| `args.go` | Query argument handling |
| `watcher.go` | File change detection for hot reload |
| `rolestmt.go` | Role statement compilation |
| `trace.go` | Tracing/observability support |

### Main Data Structures

```go
type graphjinEngine struct {
    conf          *Config              // Configuration
    db            *sql.DB              // Database connection
    dbinfo        *sdata.DBInfo        // Database schema info
    schema        *sdata.DBSchema      // Compiled schema
    allowList     *allow.List          // Persisted queries whitelist
    qcodeCompiler *qcode.Compiler      // GraphQL to intermediate code
    psqlCompiler  *psql.Compiler       // Intermediate to SQL
    cache         Cache                // Query result cache
    roles         map[string]*Role     // Role definitions
}

type Result struct {
    Data       []byte              // JSON result
    SQL        string              // Generated SQL
    Errors     []Error             // Validation errors
    Validation []qcode.ValidErr    // Type validation errors
}
```

### Internal Packages

#### `/core/internal/graph` - GraphQL Lexer and Parser

**Purpose**: Tokenization and parsing of GraphQL syntax into an Abstract Syntax Tree (AST)

| File | Purpose |
|------|---------|
| `lex.go` | Tokenization of GraphQL syntax |
| `parse.go` | Full GraphQL parser producing AST |
| `schema.go` | Schema definition parsing |
| `utils.go` | Lexer utilities |
| `stack.go` | Parser state stack |

**Key Types**:
```go
type Operation struct {
    Type   ParserType    // Query, Mutation, Subscription
    Name   string        // Operation name
    Fields []Field       // Top-level fields
    VarDef []VarDef      // Variable definitions
}

type Field struct {
    Name     string       // Field name
    Alias    string       // Field alias
    Args     []Arg        // Arguments
    Children []int32      // Child field indices
}
```

#### `/core/internal/qcode` - Query Compilation (GraphQL → Intermediate)

**Purpose**: Convert parsed GraphQL into an intermediate representation (QCode) that tracks:
- What tables to join
- What columns to fetch
- What filters to apply
- Relationship traversal

| File | Purpose |
|------|---------|
| `qcode.go` | Main compilation structures |
| `config.go` | Compiler configuration for roles and tables |
| `valid.go` | Query validation logic |
| `args.go` | Argument parsing and type conversion |
| `fields.go` | Field selection handling |
| `mutate.go` | Mutation operation compilation |
| `fn.go` | Function calls (COUNT, SUM, etc.) |
| `exp.go` | Expression/filter compilation |
| `orderby.go` | ORDER BY compilation |
| `dir.go` | GraphQL directive handling (@skip, @include) |
| `schema.go` | Schema parsing from db.graphql files |

**Key Types**:
```go
type QCode struct {
    Type    QType       // Query, Mutation, Insert, Update, Delete, Upsert
    Selects []Select    // Tables/fields to fetch
    Roots   []int32     // Root selectors
    Remotes int32       // Remote API joins count
}

type Select struct {
    Table   string      // Table name
    Fields  []Field     // Columns to fetch
    Where   Filter      // WHERE clause conditions
    OrderBy []OrderBy   // ORDER BY definitions
    Paging  Paging      // LIMIT/OFFSET
    Children []int32    // Related tables
}

type Exp struct {
    Op    ExpOp         // Operator: =, >, <, LIKE, IN, etc.
    Left  struct {Col, Val}   // Left side of expression
    Right struct {Col, Val}   // Right side of expression
    Children []*Exp     // AND/OR conditions
}
```

#### `/core/internal/psql` - SQL Code Generation (Intermediate → SQL)

**Purpose**: Convert QCode into optimized SQL for PostgreSQL/MySQL

| File | Purpose |
|------|---------|
| `query.go` | Main SQL compiler entry point |
| `insert.go` | INSERT statement generation |
| `update.go` | UPDATE statement generation |
| `mutate.go` | Mutation SQL handling |
| `columns.go` | Column selection SQL |
| `exp.go` | SQL expression generation (WHERE, HAVING) |
| `fn.go` | SQL function calls |
| `util.go` | SQL utilities |
| `metadata.go` | Prepared statement metadata |
| `recur.go` | Recursive CTE generation |

**Key Structure**:
```go
type Compiler struct {
    Vars      map[string]string    // SQL variables
    DBType    string               // postgres, mysql
    DBVersion int                  // Version-specific SQL
}
```

#### `/core/internal/sdata` - Schema Data Structures

**Purpose**: Represents database schema, tables, columns, relationships

| File | Purpose |
|------|---------|
| `schema.go` | Database schema representation |
| `tables.go` | Table metadata handling |
| `funcs.go` | Database function definitions |
| `sql.go` | SQL introspection queries for discovery |
| `dwg.go` | Directed weighted graph for relationships |
| `strings.go` | String utilities |

**Key Types**:
```go
type DBSchema struct {
    tables   []DBTable              // All tables
    tindex   map[string]nodeInfo    // Quick table lookup
    allEdges map[int32]TEdge        // Table relationships
}

type DBTable struct {
    Name        string               // Table name
    Schema      string               // Schema (public, etc.)
    Columns     []DBColumn           // Columns
    PrimaryKey  []string             // PK columns
    ForeignKeys []DBForeignKey       // FK relationships
}

type DBRel struct {
    Type  RelType                   // OneToOne, OneToMany, Polymorphic
    Left  DBRelLeft                 // Source table.column
    Right DBRelRight                // Target table.column
}
```

#### Other Internal Packages

| Package | Purpose |
|---------|---------|
| `/core/internal/valid` | Query and value validation |
| `/core/internal/allow` | Allow List (Persisted Queries) management |
| `/core/internal/jsn` | JSON processing utilities |

---

## Serv Package

**Location**: `/home/user/graphjin/serv`

### Purpose
Provides a **complete GraphQL HTTP service** with configuration management, authentication, database pooling, and WebUI. It wraps the core compiler with production features.

### Key Files and Responsibilities

#### Core Service Files

| File | Purpose | Key Functions |
|------|---------|--------------|
| `api.go` | HTTP request handlers | `GraphQL()`, `REST()`, `OpenAPI()` |
| `serv.go` | Main service implementation | HTTP server setup, graceful shutdown |
| `config.go` | Service configuration | `Config`, `Serv`, `Admin`, `Database`, `RateLimiter` |
| `routes.go` | HTTP route definitions | Sets up `/api/v1/graphql`, `/api/v1/rest`, `/api/v1/openapi.json` |

#### Initialization Files

| File | Purpose | Key Functions |
|------|---------|--------------|
| `init.go` | Service initialization | `initConfig()`, `initDB()`, `initFS()`, `validateConf()` |

#### Feature Files

| File | Purpose |
|------|---------|
| `http.go` | HTTP server setup, middleware, CORS |
| `ws.go` | WebSocket support for subscriptions |
| `db.go` | Database connection management and pooling |
| `health.go` | Health check endpoint |
| `admin.go` | Admin API for hot-deploy |
| `deploy.go` | Hot-deploy functionality |
| `webui.go` | Built-in Web UI (GraphQL explorer) |
| `telemetry.go` | OpenTelemetry integration |
| `iplimiter.go` | IP-based rate limiting |
| `filewatch.go` | Configuration file watching |
| `sqllog.go` | SQL query logging |
| `client.go` | Client utilities for testing/CLI |
| `migrate.go` | Database migration support |
| `afero.go` | Filesystem abstraction |

### Main Data Structures

```go
type HttpService struct {
    atomic.Value          // Stores graphjinService (thread-safe)
    cpath string          // Config path
}

type graphjinService struct {
    log  *zap.SugaredLogger  // Logger
    conf *Config              // Configuration
    db   *sql.DB              // Database pool
    gj   *core.GraphJin       // Core compiler instance
    srv  *http.Server         // HTTP server
}
```

### Internal Packages

| Package | Purpose |
|---------|---------|
| `/serv/internal/util` | Logging and configuration utilities |
| `/serv/internal/etags` | HTTP ETags and caching |
| `/serv/internal/tools` | JavaScript execution (Goja) |

### Integration with Core

```
HTTP Request
    ↓
[ServeHTTP Router] -------- Route matching
    ↓
[Auth Middleware] --------- JWT/JWKS validation (auth.v3)
    ↓
[API Handler] ------------- Set context values (UserID, Role)
    ↓
[core.GraphJin.GraphQL()] - Compile and execute query
    ↓
[JSON Response] ----------- Return result to client
```

---

## Cmd Package

**Location**: `/home/user/graphjin/cmd`

### Purpose
Provides **command-line interface** for GraphJin. Uses Cobra for CLI framework and wraps serv for functionality.

### Available Commands

| Command | Purpose |
|---------|---------|
| `serv`, `serve` | Run the GraphJin service |
| `new` | Create a new GraphJin application |
| `db` | Database management (create, migrate, seed) |
| `migrate` | Database migrations |
| `deploy` | Deploy a new configuration (with hot-deploy) |
| `init` | Initialize admin database |
| `version` | Show version information |

### Key Files

| File | Purpose |
|------|---------|
| `main.go` | CLI entry point |
| `cmd.go` | Root command and command setup |
| `cmd_serv.go` | Service command implementation |
| `cmd_new.go` | App creation command |
| `cmd_db.go` | Database operations |
| `cmd_migrate.go` | Database migrations |
| `cmd_admin.go` | Admin operations |
| `cmd_version.go` | Version display |

### Architecture Pattern

```
CLI Command
    ↓
setup(cpath) -------------- Load configuration
    ↓
serv.NewGraphJinService() - Create service instance
    ↓
service.Start() ----------- Run service
```

---

## Dependencies and Integration

### Core Package Dependencies (Minimal)
- `github.com/hashicorp/golang-lru/v2` - Query caching
- `golang.org/x/sync` - Concurrency primitives

### Service Package Dependencies

#### Database Drivers
- `github.com/jackc/pgx/v5` - PostgreSQL driver
- `github.com/go-sql-driver/mysql` - MySQL driver

#### Web & HTTP
- `github.com/go-chi/chi/v5` - HTTP router
- `github.com/gorilla/websocket` - WebSocket support
- `github.com/rs/cors` - CORS middleware

#### Configuration
- `github.com/spf13/viper` - Config file reading (YAML, TOML, JSON)
- `github.com/spf13/afero` - Filesystem abstraction

#### Observability
- `go.opentelemetry.io/otel` - Distributed tracing
- `go.uber.org/zap` - Structured logging

#### Authentication
- `github.com/dosco/graphjin/auth/v3` - JWT/JWKS handling
- `github.com/lestrrat-go/jwx` - JWT parsing

### Command Package Dependencies
- `github.com/spf13/cobra` - CLI framework
- `github.com/dop251/goja` - JavaScript execution
- `github.com/brianvoe/gofakeit/v6` - Fake data generation

---

## Key Design Patterns

### 1. Thread-Safe Design
- Uses `sync.atomic.Value` for zero-copy configuration swaps
- `sync.Map` for query caching
- Connection pooling via `database/sql`

### 2. Option Pattern
```go
// Both core and serv use options for extensibility
gj, err := core.NewGraphJin(conf, db,
    core.OptionSetFS(fs),
    core.OptionSetTrace(tracer),
    core.OptionSetResolver("remote_api", myResolver),
)
```

### 3. Compiler Pattern
- **Three-stage compilation**: GraphQL → QCode → SQL
- Each stage is separated and independently testable
- Compilers are reusable across requests

### 4. State Machine Pattern
- `gstate` manages query execution lifecycle
- `cstate` caches compiled statements
- Production mode: compile once, execute many
- Dev mode: compile on every request

### 5. File System Abstraction
- `FS` interface for pluggable file systems
- Allows embedded files, cloud storage, etc.

---

## Production vs Development Modes

### Production Mode
| Aspect | Behavior |
|--------|----------|
| Configuration | `core.Production = true` |
| Allow-list | Enforced - only pre-compiled queries execute |
| Introspection | Blocked |
| Schema | Static - no auto-discovery, uses saved schema |
| Security | All checks enabled |
| Compilation | Cached after first use per role/namespace |

### Development Mode
| Aspect | Behavior |
|--------|----------|
| Configuration | `core.Production = false` |
| Allow-list | Optional - any query can execute (logged) |
| Introspection | Enabled - full schema introspection |
| Schema | Dynamic - auto-discovery from database |
| Security | Some checks relaxed |
| File Watching | Config changes auto-reload service |

---

## Request Flow Diagrams

### Query Execution Flow

```
Client HTTP Request (GraphQL or REST)
    ↓
[serv.ApiHandler]
    - Auth middleware validates JWT
    - Sets UserID, Role in context
    ↓
[serv.GraphQL/REST Handler]
    - Parses request
    - Calls core.GraphJin.GraphQL()
    ↓
[core.GraphJin.GraphQL]
    1. graph.Parse() ------------ Parse GraphQL text to AST
    2. qcode.Compiler.Compile() - Validate & convert to QCode
    3. psql.Compiler.Compile() -- Generate SQL from QCode
    4. Execute SQL via database/sql
    5. Serialize result to JSON
    ↓
[Response]
    - JSON data
    - SQL query (in debug mode)
    - Errors and validation messages
```

### Role-Based Access Control (RBAC)

```
Request arrives with user ID
    ↓
[gstate.executeRoleQuery()] - If ABAC enabled, fetch user role from DB
    ↓
[qcode.Compiler.Compile()] - Applies role-specific:
    - Column visibility filters
    - Row-level security (WHERE clause)
    - Mutation restrictions
    ↓
[psql.Compiler.Compile()] - Generates role-restricted SQL
```

### Configuration Flow

```
Config File (YAML/TOML/JSON)
    ↓
[serv.ReadInConfig()] ---- Reads via Viper
    ↓
[Config] - Parsed into structs:
    - Serv (service config)
    - Core (compiler config)
    - Database (pool settings)
    - Auth (JWT/JWKS)
    - Admin (hot-deploy)
    ↓
[core.NewGraphJin()] ----- Initializes compiler
[serv.NewGraphJinService()] - Initializes service
```

### Hot-Deploy Process

```
Admin API: POST /admin/deploy with new config
    ↓
[serv.Deploy Handler]
    - Validates new config
    - Hash checks
    ↓
[core.Reload()]
    - Re-discovers database schema
    - Recompiles allow-list
    - Reinitializes compilers
    ↓
[serv.GraphJin atomic.Store]
    - Atomically switches to new instance
    ↓
Old instance cleanup
```

---

## Quick Reference: Important File Locations

### Core Package
- Main API: `/core/api.go`
- Configuration: `/core/config.go`
- State Machine: `/core/gstate.go`
- GraphQL Parser: `/core/internal/graph/parse.go`
- QCode Compiler: `/core/internal/qcode/qcode.go`
- SQL Generator: `/core/internal/psql/query.go`
- Schema: `/core/internal/sdata/schema.go`

### Serv Package
- HTTP Handlers: `/serv/api.go`
- Server Setup: `/serv/serv.go`
- Configuration: `/serv/config.go`
- Routes: `/serv/routes.go`
- Database: `/serv/db.go`

### Cmd Package
- Entry Point: `/cmd/main.go`
- Commands: `/cmd/cmd.go`
- Service Command: `/cmd/cmd_serv.go`

---

## Summary

GraphJin is a **layered, production-ready system** for automatic API generation from GraphQL:

1. **Core Layer** - Pure compiler (no web deps)
   - Parses GraphQL → generates SQL
   - Handles RBAC, joins, relationships
   - Extensible with custom resolvers

2. **Service Layer** - HTTP wrapper
   - REST/GraphQL endpoints
   - Authentication (JWT/JWKS)
   - Configuration management
   - Hot-deploy capability

3. **CLI Layer** - User-facing tools
   - Application scaffolding
   - Database management
   - Service operations

The architecture emphasizes **separation of concerns**, **thread-safety**, and **production-readiness** while maintaining a simple external API for developers.
