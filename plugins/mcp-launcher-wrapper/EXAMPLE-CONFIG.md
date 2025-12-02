# Example MCP Configuration

This document provides example configurations for common MCP server setups.

## Example 1: Basic Node.js MCP Servers

```bash
#!/bin/bash

# Base directory
export MCP_SERVERS_BASE_DIR="${HOME}/mcp-servers"

# Server definitions
declare -A MCP_SERVERS=(
    ["wiki-server"]="node:${MCP_SERVERS_BASE_DIR}/wiki-server/build/index.js"
    ["git-server"]="node:${MCP_SERVERS_BASE_DIR}/git-server/build/index.js"
)

get_server_env() {
    local server_name="$1"

    case "$server_name" in
        wiki-server)
            echo "CONFLUENCE_TOKEN=${CONFLUENCE_TOKEN}"
            echo "CONFLUENCE_BASE_URL=${CONFLUENCE_BASE_URL}"
            ;;
        git-server)
            echo "GITHUB_TOKEN=${GITHUB_TOKEN}"
            echo "GITHUB_API_URL=${GITHUB_API_URL:-https://api.github.com}"
            ;;
    esac
}

export -f get_server_env
```

## Example 2: Multiple Runtime Environments

```bash
#!/bin/bash

export MCP_SERVERS_BASE_DIR="${HOME}/projects/mcp"

declare -A MCP_SERVERS=(
    # Node.js servers
    ["api-server"]="node:${MCP_SERVERS_BASE_DIR}/api-server/dist/index.js"

    # Python servers
    ["ml-server"]="python3:${MCP_SERVERS_BASE_DIR}/ml-server/src/main.py"

    # Deno servers
    ["edge-server"]="deno:run:--allow-all:${MCP_SERVERS_BASE_DIR}/edge-server/mod.ts"

    # Binary executables
    ["rust-server"]="${MCP_SERVERS_BASE_DIR}/rust-server/target/release/mcp-rust:"
)

get_server_env() {
    local server_name="$1"

    case "$server_name" in
        api-server)
            echo "API_KEY=${API_KEY}"
            echo "DATABASE_URL=${DATABASE_URL}"
            echo "REDIS_URL=${REDIS_URL}"
            ;;
        ml-server)
            echo "MODEL_PATH=${HOME}/models"
            echo "PYTHONPATH=${MCP_SERVERS_BASE_DIR}/ml-server/src"
            ;;
        edge-server)
            echo "DENO_ENV=production"
            ;;
        rust-server)
            echo "RUST_LOG=info"
            echo "TOKIO_WORKER_THREADS=4"
            ;;
    esac
}

export -f get_server_env
```

## Example 3: Enterprise Setup with Corporate Certificates

```bash
#!/bin/bash

# Corporate environment setup
export MCP_SERVERS_BASE_DIR="/opt/company/mcp-servers"
export MCP_PID_DIR="${HOME}/.mcp/pids"
export MCP_LOG_DIR="${HOME}/.mcp/logs"
export MCP_FIFO_DIR="${HOME}/.mcp/fifos"

# Corporate certificate
export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/company-ca.pem"

declare -A MCP_SERVERS=(
    ["jira-server"]="node:${MCP_SERVERS_BASE_DIR}/jira-server/build/index.js"
    ["confluence-server"]="node:${MCP_SERVERS_BASE_DIR}/confluence-server/build/index.js"
    ["jenkins-server"]="node:${MCP_SERVERS_BASE_DIR}/jenkins-server/build/index.js"
    ["gitlab-server"]="node:${MCP_SERVERS_BASE_DIR}/gitlab-server/build/index.js"
)

get_server_env() {
    local server_name="$1"

    case "$server_name" in
        jira-server)
            echo "JIRA_HOME=https://jira.company.com"
            echo "JIRA_PAT=${JIRA_PAT}"
            echo "NODE_TLS_REJECT_UNAUTHORIZED=0"
            echo "NODE_EXTRA_CA_CERTS=${NODE_EXTRA_CA_CERTS}"
            ;;
        confluence-server)
            echo "CONFLUENCE_BASE_URL=https://confluence.company.com"
            echo "CONFLUENCE_TOKEN=${CONFLUENCE_TOKEN}"
            echo "NODE_TLS_REJECT_UNAUTHORIZED=0"
            ;;
        jenkins-server)
            echo "JENKINS_URL=https://jenkins.company.com"
            echo "JENKINS_USERNAME=${JENKINS_USERNAME}"
            echo "JENKINS_API_TOKEN=${JENKINS_API_TOKEN}"
            echo "NODE_TLS_REJECT_UNAUTHORIZED=0"
            ;;
        gitlab-server)
            echo "GITLAB_URL=https://gitlab.company.com"
            echo "GITLAB_TOKEN=${GITLAB_TOKEN}"
            echo "NODE_TLS_REJECT_UNAUTHORIZED=0"
            ;;
    esac
}

export -f get_server_env
```

## Example 4: Development vs Production Environments

```bash
#!/bin/bash

# Detect environment
ENVIRONMENT="${MCP_ENV:-development}"

if [[ "$ENVIRONMENT" == "production" ]]; then
    export MCP_SERVERS_BASE_DIR="/var/lib/mcp-servers"
    export MCP_LOG_DIR="/var/log/mcp-servers"
else
    export MCP_SERVERS_BASE_DIR="${HOME}/dev/mcp-servers"
    export MCP_LOG_DIR="${HOME}/.mcp/logs"
fi

export MCP_PID_DIR="${HOME}/.mcp/pids"
export MCP_FIFO_DIR="${HOME}/.mcp/fifos"

declare -A MCP_SERVERS=(
    ["database-server"]="node:${MCP_SERVERS_BASE_DIR}/database-server/build/index.js"
    ["cache-server"]="node:${MCP_SERVERS_BASE_DIR}/cache-server/build/index.js"
)

get_server_env() {
    local server_name="$1"

    case "$server_name" in
        database-server)
            if [[ "$ENVIRONMENT" == "production" ]]; then
                echo "DB_HOST=prod-db.company.com"
                echo "DB_PORT=5432"
                echo "DB_NAME=production"
            else
                echo "DB_HOST=localhost"
                echo "DB_PORT=5432"
                echo "DB_NAME=development"
            fi
            echo "DB_USER=${DB_USER}"
            echo "DB_PASSWORD=${DB_PASSWORD}"
            ;;
        cache-server)
            if [[ "$ENVIRONMENT" == "production" ]]; then
                echo "REDIS_URL=redis://prod-redis.company.com:6379"
            else
                echo "REDIS_URL=redis://localhost:6379"
            fi
            ;;
    esac
}

export -f get_server_env
```

## Example 5: Using Environment Files

```bash
#!/bin/bash

export MCP_SERVERS_BASE_DIR="${HOME}/mcp-servers"

# Load from .env file if it exists
if [[ -f "${HOME}/.mcp/.env" ]]; then
    export $(cat "${HOME}/.mcp/.env" | grep -v '^#' | xargs)
fi

declare -A MCP_SERVERS=(
    ["app-server"]="node:${MCP_SERVERS_BASE_DIR}/app-server/build/index.js"
)

get_server_env() {
    local server_name="$1"

    case "$server_name" in
        app-server)
            # Pass through all loaded environment variables
            env | grep -E '^(API_|DB_|REDIS_|AWS_)' | while read line; do
                echo "$line"
            done
            ;;
    esac
}

export -f get_server_env
```

## Setting Environment Variables

### Option 1: System Environment Variables

Set in your `~/.bashrc` or `~/.zshrc`:

```bash
export CONFLUENCE_TOKEN="your_token"
export GITHUB_TOKEN="your_token"
export JIRA_PAT="your_pat"
```

Then reference in config:
```bash
echo "CONFLUENCE_TOKEN=${CONFLUENCE_TOKEN}"
```

### Option 2: Separate .env File

Create `~/.mcp/.env`:
```
CONFLUENCE_TOKEN=your_token
GITHUB_TOKEN=your_token
JIRA_PAT=your_pat
```

Load in config:
```bash
source "${HOME}/.mcp/.env"
```

### Option 3: Hardcode (Not Recommended)

Only use for non-sensitive values or testing:
```bash
echo "CONFLUENCE_BASE_URL=https://your-instance.com"
```

## Custom Directory Layout

You can customize where MCP stores its files:

```bash
# Use XDG Base Directory specification
export MCP_PID_DIR="${XDG_RUNTIME_DIR:-/tmp}/mcp/pids"
export MCP_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mcp/logs"
export MCP_FIFO_DIR="${XDG_RUNTIME_DIR:-/tmp}/mcp/fifos"

# Or use a centralized location
export MCP_ROOT="${HOME}/.mcp"
export MCP_PID_DIR="${MCP_ROOT}/pids"
export MCP_LOG_DIR="${MCP_ROOT}/logs"
export MCP_FIFO_DIR="${MCP_ROOT}/fifos"
```

## Testing Your Configuration

After creating your `mcp-config.sh`, test it:

```bash
# Source the config
source mcp-config.sh

# Check variables are set
echo "MCP_SERVERS_BASE_DIR: $MCP_SERVERS_BASE_DIR"
echo "MCP_PID_DIR: $MCP_PID_DIR"

# List configured servers
for server in "${!MCP_SERVERS[@]}"; do
    echo "Server: $server -> ${MCP_SERVERS[$server]}"
done

# Test environment function
get_server_env wiki-server
```

## Security Best Practices

1. **Never commit credentials**:
   ```bash
   echo "mcp-config.sh" >> .gitignore
   ```

2. **Use restrictive permissions**:
   ```bash
   chmod 600 mcp-config.sh
   ```

3. **Use environment variables** instead of hardcoding

4. **Rotate tokens regularly**

5. **Use least-privilege access** - only grant necessary permissions

6. **Consider using a secrets manager** for production environments
