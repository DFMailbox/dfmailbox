#!/usr/bin/env bash

ENV_FILE=".env"
echo "This utility will walk you through creating a docker compose $ENV_FILE file."
echo ""

read -p "PostgreSQL Password: " DFM_POSTGRES_PASSWORD
read -p "Host domain e.g. example.com: " DFM_HOST

read -p "Enter port (default: 8080): " DFM_PORT
if [ -z "$DFM_PORT" ]; then
  DFM_PORT=8080
fi

read -p "Secret key (default: generate): " DFM_SECRET_KEY
if [ -z "$DFM_SECRET_KEY" ]; then
  DFM_SECRET_KEY=$(openssl genpkey -algorithm ED25519 -outform DER | tail -c 32 | openssl base64 -A)
fi

if [ -f $ENV_FILE ]; then
  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color
  echo -e "${YELLOW}WARNING: $ENV_FILE EXISTS!"
  echo -e "The file isn't overriden yet. Press Ctrl+C to exit early${NC}"
  read -p "Press enter to proceed..."
fi

# Write env file
cat << EOF > "$ENV_FILE"
DFM_POSTGRES_PASSWORD="$DFM_POSTGRES_PASSWORD"
DFM_POSTGRES_PORT=5432
DFM_PORT="$DFM_PORT"
DFM_HOST="$DFM_HOST"
DFM_SECRET_KEY="$DFM_SECRET_KEY"

# Change this to 'dev' for development
TARGET="prod"
EOF

echo ""
echo "$ENV_FILE file generated!"
echo "PS: Please don't commit this file into git, use .gitignore to ignore it"
