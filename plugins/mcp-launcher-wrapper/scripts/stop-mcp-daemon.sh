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

# Stop MCP Server Daemon

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

DAEMON_PID_FILE="${MCP_PID_DIR}/mcp-daemon.pid"
MCP_MANAGER="${SCRIPT_DIR}/mcp-manager.sh"

if [[ ! -f "$DAEMON_PID_FILE" ]]; then
    echo "MCP daemon is not running"
    exit 0
fi

DAEMON_PID=$(cat "$DAEMON_PID_FILE")

if ps -p "$DAEMON_PID" > /dev/null 2>&1; then
    echo "Stopping MCP daemon (PID: $DAEMON_PID)..."

    # Stop all servers first
    "$MCP_MANAGER" stop

    # Kill the daemon
    kill -TERM "$DAEMON_PID" 2>/dev/null || true

    # Wait for it to die
    sleep 2

    if ps -p "$DAEMON_PID" > /dev/null 2>&1; then
        kill -KILL "$DAEMON_PID" 2>/dev/null || true
    fi

    rm -f "$DAEMON_PID_FILE"
    echo "MCP daemon stopped"
else
    echo "MCP daemon PID file exists but process is not running"
    rm -f "$DAEMON_PID_FILE"
fi
