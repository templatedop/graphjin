#!/bin/bash
# Quick setup script for GraphJin

echo "Setting up GraphJin configuration..."

# Create config directory if it doesn't exist
mkdir -p config/migrations config/queries

# Create minimal dev.yml
cat > config/dev.yml <<'EOF'
app_name: "GraphJin Quick Start"
host_port: 0.0.0.0:8080
web_ui: true
production: false

log_level: "info"
log_format: "plain"
debug: true
enable_tracing: true

database:
  type: postgres
  host: localhost
  port: 5432
  dbname: graphjin_dev
  user: postgres
  password: postgres

auth:
  type: none

secret_key: "supercalifragilisticexpialidocious12"
cors_allowed_origins: ["*"]

blocklist:
  - schema_migrations
  - ar_internal_metadata

roles:
  - name: anon
    tables:
      - name: users
        query:
          limit: 10
EOF

echo "✓ Created config/dev.yml"

# Create sample migration
cat > config/migrations/001_initial.sql <<'EOF'
-- Sample schema
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Sample data
INSERT INTO users (email, name) VALUES
  ('test@example.com', 'Test User')
ON CONFLICT (email) DO NOTHING;
EOF

echo "✓ Created config/migrations/001_initial.sql"

# Create sample query
cat > config/queries/get_users.gql <<'EOF'
query getUsers {
  users {
    id
    email
    name
    created_at
  }
}
EOF

echo "✓ Created config/queries/get_users.gql"

echo ""
echo "Setup complete! 🎉"
echo ""
echo "To run GraphJin:"
echo "  1. Ensure your database 'graphjin_dev' exists"
echo "  2. cd cmd"
echo "  3. go run . serve --path ../config"
echo ""
echo "Or build first:"
echo "  1. cd cmd"
echo "  2. go build -o graphjin ."
echo "  3. ./graphjin serve --path ../config"
echo ""
echo "Access at: http://localhost:8080"
