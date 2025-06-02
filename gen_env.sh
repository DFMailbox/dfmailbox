#!/usr/bin/env bash

# I admit, this is a vibe coded but checked file

prompt_boolean() {
    local question="$1"
    local default_answer="${2:-y}"

    # Convert default to lowercase for easier comparison
    default_answer=$(echo "$default_answer" | tr '[:upper:]' '[:lower:]')

    # Validate default answer
    if [[ "$default_answer" != "y" && "$default_answer" != "n" ]]; then
        echo "Error: Default answer must be 'y' or 'n'." >&2
        return 2
    fi

    local options="[Y/n]"
    if [[ "$default_answer" == "n" ]]; then
        options="[y/N]"
    fi

    while true; do
        read -rp "$question $options: " answer
        answer=$(echo "$answer" | tr '[:upper:]:' '[:lower:]') # Convert input to lowercase

        if [[ -z "$answer" ]]; then # If input is empty, use default
            answer="$default_answer"
        fi

        case "$answer" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo "Please answer 'yes' or 'no'."
                ;;
        esac
    done
}

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

if prompt_boolean "Are you using Nginx?" "n"; then
  DFM_IS_NGINX="true"
else
  DFM_IS_NGINX="false"
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
DFM_IS_NGINX=$DFM_IS_NGINX

# Change this to 'dev' for development
TARGET="prod"
EOF

echo ""
echo "$ENV_FILE file generated!"
echo "PS: Please don't commit this file into git, use .gitignore to ignore it"
