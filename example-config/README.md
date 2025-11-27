# Example GraphJin Configuration

This directory contains a complete example configuration for GraphJin.

## Directory Structure

```
example-config/
├── dev.yml                          # Development configuration
├── migrations/                      # Database migrations
│   └── 001_initial_schema.sql      # Initial schema with sample data
└── queries/                         # Allow-list queries (for production)
    ├── get_products.gql            # Query to get all products
    └── get_user.gql                # Query to get user by ID
```

## Quick Start

### 1. Set Up Your Database

First, create a PostgreSQL database:

```bash
createdb graphjin_dev
```

Or for MySQL:

```bash
mysql -e "CREATE DATABASE graphjin_dev;"
```

### 2. Update Configuration

Edit `dev.yml` and update the database credentials:

```yaml
database:
  type: postgres        # or mysql
  host: localhost
  port: 5432           # 3306 for MySQL
  dbname: graphjin_dev
  user: postgres       # your database user
  password: postgres   # your database password
```

### 3. Build GraphJin

```bash
cd ../cmd
go build -o graphjin .
```

### 4. Run Migrations

Apply the database migrations:

```bash
cd ../example-config
../cmd/graphjin migrate --path .
```

This will create the following tables:
- `users`
- `products`
- `orders`
- `order_items`

And populate them with sample data.

### 5. Start the Server

```bash
../cmd/graphjin serve --path .
```

The server will start on `http://localhost:8080`

## Access Points

Once the server is running:

- **Web UI**: http://localhost:8080
- **GraphQL API**: http://localhost:8080/api/v1/graphql
- **REST API**: http://localhost:8080/api/v1/rest
- **OpenAPI Spec**: http://localhost:8080/api/v1/openapi.json
- **Health Check**: http://localhost:8080/health

## Example Queries

### Using the Web UI

Open http://localhost:8080 in your browser and try these queries:

#### Get All Users

```graphql
query {
  users {
    id
    email
    name
    created_at
  }
}
```

#### Get Published Products

```graphql
query {
  products(where: { is_published: { eq: true } }) {
    id
    name
    description
    price
    stock
  }
}
```

#### Get User with Their Orders

```graphql
query {
  users(id: 1) {
    id
    email
    name
    orders {
      id
      total
      status
      created_at
      order_items {
        id
        quantity
        price
        product {
          name
        }
      }
    }
  }
}
```

### Using curl

#### Simple Query

```bash
curl http://localhost:8080/api/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ users { id email name } }"
  }'
```

#### Query with Variables

```bash
curl http://localhost:8080/api/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query GetUser($id: Int!) { users(id: $id) { id email name } }",
    "variables": {"id": 1}
  }'
```

#### Using REST API

GraphJin automatically creates REST endpoints:

```bash
# Get all users
curl http://localhost:8080/api/v1/rest/users

# Get user by ID
curl http://localhost:8080/api/v1/rest/users/1

# Get products with filters
curl "http://localhost:8080/api/v1/rest/products?is_published=true&limit=5"
```

## Configuration Features

This example demonstrates:

✅ **Development Mode**
- All queries allowed (no allow-list enforcement)
- GraphQL introspection enabled
- Web UI enabled
- Debug logging and tracing

✅ **Database Connection**
- Connection pooling
- Sample migrations

✅ **Authentication**
- Set to `none` for easy testing
- Can be changed to `jwt` or `header`

✅ **RBAC (Role-Based Access Control)**
- `anon` role: Limited access for anonymous users
- `user` role: Authenticated user access with filters

✅ **Security Features**
- Blocklist for sensitive fields
- Row-level security with filters
- Query limits

## Next Steps

1. **Explore the Schema**: Use the Web UI to browse the auto-generated GraphQL schema

2. **Try Mutations**: Create, update, or delete data
   ```graphql
   mutation {
     product(insert: {
       name: "New Product"
       price: 49.99
       stock: 100
       is_published: true
     }) {
       id
       name
     }
   }
   ```

3. **Set Up Authentication**: Change `auth.type` to `jwt` and configure JWT settings

4. **Add More Tables**: Create new migration files in `migrations/`

5. **Test Production Mode**:
   - Set `production: true` in config
   - Only queries from `queries/` folder will work
   - Introspection will be disabled

## Troubleshooting

### Database Connection Failed

Check that:
- Database is running: `pg_isready` (PostgreSQL) or `mysqladmin ping` (MySQL)
- Credentials are correct in `dev.yml`
- Database exists: `psql -l | grep graphjin_dev`

### Port Already in Use

Change the port in `dev.yml`:

```yaml
host_port: 0.0.0.0:3000
```

### Migrations Not Applied

Run migrations explicitly:

```bash
../cmd/graphjin migrate --path .
```

Check migration status in your database:
```sql
SELECT * FROM schema_migrations;
```

## Support

For more information, see:
- `../GETTING_STARTED.md` - Complete getting started guide
- `../TECHNICAL_DOCUMENTATION.md` - Architecture and codebase details
