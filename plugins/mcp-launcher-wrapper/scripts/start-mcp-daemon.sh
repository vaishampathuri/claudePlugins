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

# MCP Server Daemon Starter
# Ensures MCP servers are always running in the background with auto-restart

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"

# Load configuration
CONFIG_FILE="${PLUGIN_DIR}/mcp-config.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    echo "Please copy mcp-config.template.sh to mcp-config.sh and configure it."
    exit 1
fi

source "$CONFIG_FILE"

MCP_MANAGER="${SCRIPT_DIR}/mcp-manager.sh"
DAEMON_PID_FILE="${MCP_PID_DIR}/mcp-daemon.pid"
DAEMON_LOG="${MCP_LOG_DIR}/mcp-daemon.log"

# Ensure directories exist
mkdir -p "$MCP_PID_DIR"
mkdir -p "$MCP_LOG_DIR"

# Check if daemon is already running
if [[ -f "$DAEMON_PID_FILE" ]]; then
    DAEMON_PID=$(cat "$DAEMON_PID_FILE")
    if ps -p "$DAEMON_PID" > /dev/null 2>&1; then
        echo "MCP daemon already running (PID: $DAEMON_PID)"
        exit 0
    else
        rm -f "$DAEMON_PID_FILE"
    fi
fi

# Function to monitor and restart servers
monitor_servers() {
    # Load server list from config
    source "$CONFIG_FILE"

    while true; do
        # Check each server every 30 seconds
        for server in "${!MCP_SERVERS[@]}"; do
            if ! "$MCP_MANAGER" status "$server" | grep -q "RUNNING"; then
                echo "[$(date)] $server is down, restarting..." >> "$DAEMON_LOG"
                "$MCP_MANAGER" start "$server" >> "$DAEMON_LOG" 2>&1
            fi
        done
        sleep 30
    done
}

# Start the daemon
echo "Starting MCP server daemon..."
echo "$$" > "$DAEMON_PID_FILE"

# Initial server start
"$MCP_MANAGER" start >> "$DAEMON_LOG" 2>&1

# Start monitoring in background
monitor_servers &
MONITOR_PID=$!

echo "MCP daemon started (PID: $$, Monitor PID: $MONITOR_PID)"
echo "Logs: $DAEMON_LOG"

# Wait for monitor process
wait $MONITOR_PID
