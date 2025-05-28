#!/usr/bin/env bash

ENV_FILE=".env"
echo "This utility will walk you through creating a docker compose $ENV_FILE file."
echo ""

read -p "PostgreSQL Password: " DFQ_POSTGRES_PASSWORD
read -p "Host domain e.g. example.com: " DFQ_HOST

read -p "Enter port (default: 8080): " DFQ_PORT
if [ -z "$DFQ_PORT" ]; then
  DFQ_PORT=8080
fi

read -p "Secret key (default: generate): " DFQ_SECRET_KEY
if [ -z "$DFQ_SECRET_KEY" ]; then
  DFQ_SECRET_KEY=$(openssl genpkey -algorithm ED25519 | awk '/^-----BEGIN PRIVATE KEY-----/{p=1;next}/^-----END PRIVATE KEY-----/{p=0}p')
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
DFQ_POSTGRES_PASSWORD="$DFQ_POSTGRES_PASSWORD"
DFQ_HOST="$DFQ_HOST"
DFQ_SECRET_KEY="$DFQ_SECRET_KEY"
DFQ_PORT="$DFQ_PORT"

# Change this to 'dev' for development
TARGET="prod"
EOF

echo ""
echo "$ENV_FILE file generated!"
echo "PS: Please don't commit this file into git, use .gitignore to ignore it"
