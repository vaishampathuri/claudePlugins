#!/bin/bash
# Copyright 2025 Barsa Nayak
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# MCP Server Configuration Template
# Copy this file to mcp-config.sh and customize for your environment

# ==============================================================================
# DIRECTORY CONFIGURATION
# ==============================================================================

# Base directory where your MCP servers are located
export MCP_SERVERS_BASE_DIR="${HOME}/path/to/your/mcp-servers"

# Directory for PID files (process tracking)
export MCP_PID_DIR="${HOME}/.claude/pids"

# Directory for log files
export MCP_LOG_DIR="${HOME}/.claude/logs/mcp-servers"

# Directory for FIFO pipes (stdin management)
export MCP_FIFO_DIR="${HOME}/.claude/fifos"

# ==============================================================================
# SERVER DEFINITIONS
# ==============================================================================

# Define your MCP servers as an associative array
# Format: SERVER_NAME=COMMAND:PATH_TO_SCRIPT
declare -A MCP_SERVERS=(
    ["wiki-server"]="node:${MCP_SERVERS_BASE_DIR}/wiki-server/build/index.js"
    ["git-server"]="node:${MCP_SERVERS_BASE_DIR}/git-server/build/src/index.js"
    ["jira-server"]="node:${MCP_SERVERS_BASE_DIR}/jira-server/build/index.js"
    ["jenkins-server"]="node:${MCP_SERVERS_BASE_DIR}/jenkins-server/build/index.js"
)

# ==============================================================================
# ENVIRONMENT VARIABLES PER SERVER
# ==============================================================================

# Function to get environment variables for each server
# Customize this function with your server-specific environment variables
get_server_env() {
    local server_name="$1"

    case "$server_name" in
        wiki-server)
            echo "CONFLUENCE_TOKEN=your_confluence_token_here"
            echo "CONFLUENCE_BASE_URL=https://your-confluence-instance.com"
            echo "NODE_TLS_REJECT_UNAUTHORIZED=0"
            ;;
        git-server)
            echo "GITHUB_TOKEN=your_github_token_here"
            echo "GITHUB_API_URL=https://api.github.com"
            echo "NODE_TLS_REJECT_UNAUTHORIZED=0"
            ;;
        jira-server)
            echo "JIRA_HOME=https://your-jira-instance.com"
            echo "JIRA_PAT=your_jira_pat_here"
            echo "NODE_TLS_REJECT_UNAUTHORIZED=0"
            ;;
        jenkins-server)
            echo "JENKINS_URL=https://your-jenkins-instance.com"
            echo "JENKINS_USERNAME=your_username"
            echo "JENKINS_API_TOKEN=your_jenkins_token"
            echo "NODE_TLS_REJECT_UNAUTHORIZED=0"
            ;;
    esac
}

# Export the function so it's available to other scripts
export -f get_server_env

# ==============================================================================
# CONFIGURATION INSTRUCTIONS
# ==============================================================================
#
# 1. Copy this template:
#    cp mcp-config.template.sh mcp-config.sh
#
# 2. Edit mcp-config.sh with your actual values:
#    - Update MCP_SERVERS_BASE_DIR to point to your MCP servers directory
#    - Modify the MCP_SERVERS array with your server names and paths
#    - Update get_server_env() function with your environment variables
#
# 3. Source this config in the mcp-manager.sh script:
#    source "$(dirname "$0")/mcp-config.sh"
#
# 4. Keep mcp-config.sh private (add to .gitignore) to protect your tokens
#
# ==============================================================================
