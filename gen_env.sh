#!/usr/bin/env bash

ENV_FILE=".env"
echo "This utility will walk you through creating a docker compose $ENV_FILE file."
echo "If you are not sure, follow what the () say"
echo ""
generate_random_string() {
  openssl rand "$1" | base64 -w 0 | tr '+/' '-_'
}

read -p "PostgreSQL Password (a strong password): " DFPS_POSTGRES_PASSWORD
read -p "DFPS_DOMAIN (e.g. example.com): " DFPS_DOMAIN

read -p "JWT key (leave blank to generate): " DFPS_JWT_KEY
if [ -z "$DFPS_JWT_KEY" ]; then
  DFPS_JWT_KEY=$(generate_random_string 64)
  echo "Generated jwt key: $DFPS_JWT_KEY"
fi

read -p "Secret key (leave blank to generate): " DFPS_SECRET_KEY
if [ -z "$DFPS_SECRET_KEY" ]; then
  DFPS_SECRET_KEY=$(generate_random_string 32)
  echo "Secret key: $DFPS_SECRET_KEY"
fi

read -p "Enter DFPS_PORT (8080): " DFPS_PORT
if [ -z "$DFPS_PORT" ]; then
  DFPS_PORT=8080
  echo "Using default DFPS_PORT: $DFPS_PORT"
fi

# Write env file
cat << EOF > "$ENV_FILE"
DFPS_POSTGRES_PASSWORD=$DFPS_POSTGRES_PASSWORD
DFPS_DOMAIN=$DFPS_DOMAIN
DFPS_JWT_KEY=$DFPS_JWT_KEY
DFPS_SECRET_KEY=$DFPS_SECRET_KEY
DFPS_PORT=$DFPS_PORT
EOF

echo ""
echo "$ENV_FILE file generated!"
echo "PS: Please don't commit this file into git, use .gitignore to ignore it"
