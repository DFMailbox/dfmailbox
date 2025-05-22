#!/usr/bin/env bash

ENV_FILE=".env"
echo "This utility will walk you through creating a docker compose $ENV_FILE file."
echo "If you are not sure, follow what the () say"
echo ""
generate_random_string() {
  openssl rand "$1" | base64 -w 0 | tr '+/' '-_'
}

read -p "PostgreSQL Password (a strong password): " DFQ_POSTGRES_PASSWORD
read -p "Base path (e.g. example.com/dfqueue): " DFQ_PATH

read -p "JWT key (leave blank to generate): " DFQ_JWT_KEY
if [ -z "$DFQ_JWT_KEY" ]; then
  DFQ_JWT_KEY=$(generate_random_string 64)
  echo "Generated jwt key: $DFQ_JWT_KEY"
fi

read -p "Secret key (leave blank to generate): " DFQ_SECRET_KEY
if [ -z "$DFQ_SECRET_KEY" ]; then
  DFQ_SECRET_KEY=$(generate_random_string 32)
  echo "Secret key: $DFQ_SECRET_KEY"
fi

read -p "Enter DFQ_PORT (8080): " DFQ_PORT
if [ -z "$DFQ_PORT" ]; then
  DFQ_PORT=8080
  echo "Using default DFQ_PORT: $DFQ_PORT"
fi

# Write env file
cat << EOF > "$ENV_FILE"
DFQ_POSTGRES_PASSWORD="$DFQ_POSTGRES_PASSWORD"
DFQ_PATH="$DFQ_PATH"
DFQ_JWT_KEY="$DFQ_JWT_KEY"
DFQ_SECRET_KEY="$DFQ_SECRET_KEY"
DFQ_PORT="$DFQ_PORT"

# Change this to `dev` for development
TARGET="prod"
EOF

echo ""
echo "$ENV_FILE file generated!"
echo "PS: Please don't commit this file into git, use .gitignore to ignore it"
