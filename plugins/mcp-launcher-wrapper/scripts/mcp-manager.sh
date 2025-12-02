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

# MCP Server Background Manager (STDIO-Compatible)
# Manages MCP servers that use stdio protocol by keeping stdin open

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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "$MCP_PID_DIR"
mkdir -p "$MCP_LOG_DIR"
mkdir -p "$MCP_FIFO_DIR"

# Logging functions
log() {
    echo -e "${BLUE}[MCP-MANAGER]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if a server is running
is_running() {
    local server_name="$1"
    local pid_file="${MCP_PID_DIR}/${server_name}.pid"

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Running
        else
            # PID file exists but process is dead
            rm -f "$pid_file"
            # Also clean up keeper PID
            rm -f "${MCP_PID_DIR}/${server_name}-keeper.pid" 2>/dev/null || true
            rm -f "${MCP_FIFO_DIR}/${server_name}.fifo" 2>/dev/null || true
            return 1  # Not running
        fi
    fi
    return 1  # Not running
}

# Check for duplicate processes and kill them
kill_duplicate_processes() {
    local server_name="$1"

    # Get the PID from PID file if it exists
    local tracked_pid=""
    if [[ -f "${MCP_PID_DIR}/${server_name}.pid" ]]; then
        tracked_pid=$(cat "${MCP_PID_DIR}/${server_name}.pid")
    fi

    # Find all processes for this server
    local all_pids=$(pgrep -f "/${server_name}/build" || true)

    if [[ -n "$all_pids" ]]; then
        for pid in $all_pids; do
            # Kill any process that's NOT the tracked one
            if [[ "$pid" != "$tracked_pid" ]]; then
                kill -9 "$pid" 2>/dev/null || true
                warn "Killed duplicate $server_name process (PID: $pid)"
            fi
        done
    fi
}

# Start a single MCP server in the background with stdin kept alive
start_server() {
    local server_name="$1"

    # Check if server is defined in config
    if [[ -z "${MCP_SERVERS[$server_name]:-}" ]]; then
        error "Server '$server_name' not found in configuration"
        return 1
    fi

    # Parse command and path from config
    IFS=':' read -r command path <<< "${MCP_SERVERS[$server_name]}"

    # Kill any duplicate processes first
    kill_duplicate_processes "$server_name"

    if is_running "$server_name"; then
        warn "$server_name is already running (PID: $(cat ${MCP_PID_DIR}/${server_name}.pid))"
        return 0
    fi

    log "Starting $server_name in background..."

    local log_file="${MCP_LOG_DIR}/${server_name}.log"
    local error_log="${MCP_LOG_DIR}/${server_name}.error.log"
    local pid_file="${MCP_PID_DIR}/${server_name}.pid"
    local keeper_pid_file="${MCP_PID_DIR}/${server_name}-keeper.pid"
    local fifo="${MCP_FIFO_DIR}/${server_name}.fifo"

    # Create a named pipe (FIFO) for stdin
    rm -f "$fifo"
    mkfifo "$fifo"

    # Start a background process that keeps the FIFO open
    # This prevents the server from exiting due to EOF on stdin
    (
        # Keep the FIFO open forever by tailing /dev/null into it
        tail -f /dev/null > "$fifo"
    ) &
    local keeper_pid=$!
    echo "$keeper_pid" > "$keeper_pid_file"

    # Export environment variables for this server
    local env_vars=$(get_server_env "$server_name")

    # Start the server with stdin from FIFO and proper environment
    (
        # Set environment variables
        while IFS= read -r line; do
            [[ -n "$line" ]] && export "$line"
        done <<< "$env_vars"

        # Start server with stdin from FIFO
        "$command" "$path" < "$fifo" > "$log_file" 2> "$error_log"
    ) &

    local pid=$!
    echo "$pid" > "$pid_file"

    # Wait a moment and verify it started
    sleep 2

    if is_running "$server_name"; then
        success "$server_name started successfully (PID: $pid, Keeper: $keeper_pid)"
        log "  Logs: $log_file"
        log "  Errors: $error_log"
        return 0
    else
        error "$server_name failed to start"
        # Clean up on failure
        kill -9 "$keeper_pid" 2>/dev/null || true
        rm -f "$keeper_pid_file" "$fifo"

        if [[ -f "$error_log" ]]; then
            error "Last error lines:"
            tail -n 5 "$error_log" | while read line; do
                error "  $line"
            done
        fi
        return 1
    fi
}

# Stop a single MCP server
stop_server() {
    local server_name="$1"
    local pid_file="${MCP_PID_DIR}/${server_name}.pid"
    local keeper_pid_file="${MCP_PID_DIR}/${server_name}-keeper.pid"
    local fifo="${MCP_FIFO_DIR}/${server_name}.fifo"

    if ! is_running "$server_name"; then
        warn "$server_name is not running"
        return 0
    fi

    local pid=$(cat "$pid_file")
    log "Stopping $server_name (PID: $pid)..."

    # Try graceful shutdown first (SIGTERM)
    kill -TERM "$pid" 2>/dev/null || true

    # Wait up to 5 seconds for graceful shutdown
    local count=0
    while ps -p "$pid" > /dev/null 2>&1 && [ $count -lt 5 ]; do
        sleep 1
        ((count++))
    done

    # Force kill if still running
    if ps -p "$pid" > /dev/null 2>&1; then
        warn "$server_name didn't stop gracefully, forcing..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi

    # Stop the keeper process
    if [[ -f "$keeper_pid_file" ]]; then
        local keeper_pid=$(cat "$keeper_pid_file")
        kill -9 "$keeper_pid" 2>/dev/null || true
        rm -f "$keeper_pid_file"
    fi

    # Clean up files
    rm -f "$pid_file" "$fifo"
    success "$server_name stopped"
}

# Get server status
status_server() {
    local server_name="$1"

    if is_running "$server_name"; then
        local pid=$(cat "${MCP_PID_DIR}/${server_name}.pid")
        local keeper_pid_file="${MCP_PID_DIR}/${server_name}-keeper.pid"
        local keeper_info=""
        if [[ -f "$keeper_pid_file" ]]; then
            keeper_info=" + keeper:$(cat $keeper_pid_file)"
        fi
        echo -e "${GREEN}●${NC} $server_name (PID: ${pid}${keeper_info}) - ${GREEN}RUNNING${NC}"
    else
        echo -e "${RED}●${NC} $server_name - ${RED}STOPPED${NC}"
    fi
}

# Start all MCP servers from config
start_all() {
    log "Starting all MCP servers..."
    echo ""

    # Start each server defined in config
    for server_name in "${!MCP_SERVERS[@]}"; do
        start_server "$server_name"
    done

    echo ""
    success "All MCP servers started"
    echo ""
    status_all
}

# Stop all MCP servers
stop_all() {
    log "Stopping all MCP servers..."

    for server_name in "${!MCP_SERVERS[@]}"; do
        stop_server "$server_name"
    done

    success "All MCP servers stopped"
}

# Restart all MCP servers
restart_all() {
    log "Restarting all MCP servers..."
    stop_all
    sleep 2
    start_all
}

# Show status of all servers
status_all() {
    echo ""
    echo "MCP Server Status:"
    echo "===================="

    for server_name in "${!MCP_SERVERS[@]}"; do
        status_server "$server_name"
    done

    echo ""
}

# Show logs for a server
logs() {
    local server_name="$1"
    local log_file="${MCP_LOG_DIR}/${server_name}.log"
    local error_log="${MCP_LOG_DIR}/${server_name}.error.log"

    if [[ ! -f "$log_file" ]]; then
        error "No logs found for $server_name"
        return 1
    fi

    echo ""
    echo -e "${BLUE}=== $server_name STDOUT (last 50 lines) ===${NC}"
    tail -n 50 "$log_file"

    echo ""
    echo -e "${RED}=== $server_name STDERR (last 50 lines) ===${NC}"
    tail -n 50 "$error_log"
    echo ""
}

# Follow logs in real-time
follow_logs() {
    local server_name="$1"
    local log_file="${MCP_LOG_DIR}/${server_name}.log"
    local error_log="${MCP_LOG_DIR}/${server_name}.error.log"

    if [[ ! -f "$log_file" ]]; then
        error "No logs found for $server_name"
        return 1
    fi

    echo ""
    echo -e "${BLUE}Following logs for $server_name (Ctrl+C to stop)${NC}"
    echo ""

    # Follow both stdout and stderr
    tail -f "$log_file" "$error_log"
}

# Clean up orphaned MCP processes
cleanup() {
    log "Cleaning up orphaned MCP server processes..."

    # Kill any MCP server processes not tracked by PID files
    for server_name in "${!MCP_SERVERS[@]}"; do
        local tracked_pid=""
        if [[ -f "${MCP_PID_DIR}/${server_name}.pid" ]]; then
            tracked_pid=$(cat "${MCP_PID_DIR}/${server_name}.pid")
        fi

        local all_pids=$(pgrep -f "/${server_name}/build" || true)
        if [[ -n "$all_pids" ]]; then
            for pid in $all_pids; do
                if [[ "$pid" != "$tracked_pid" ]]; then
                    kill -9 "$pid" 2>/dev/null || true
                    log "Killed orphaned $server_name process (PID: $pid)"
                fi
            done
        fi
    done

    # Kill orphaned keeper processes
    local all_keepers=$(pgrep -f "tail -f /dev/null" || true)
    if [[ -n "$all_keepers" ]]; then
        # Get tracked keeper PIDs
        local tracked_keepers=""
        for keeper_file in "${MCP_PID_DIR}"/*-keeper.pid; do
            if [[ -f "$keeper_file" ]]; then
                tracked_keepers="$tracked_keepers $(cat $keeper_file)"
            fi
        done

        # Kill any keeper not in tracked list
        for keeper_pid in $all_keepers; do
            if [[ ! " $tracked_keepers " =~ " $keeper_pid " ]]; then
                kill -9 "$keeper_pid" 2>/dev/null || true
                log "Killed orphaned keeper process (PID: $keeper_pid)"
            fi
        done
    fi

    # Clean up stale PID files
    for pid_file in "${MCP_PID_DIR}"/*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ! ps -p "$pid" > /dev/null 2>&1; then
                rm -f "$pid_file"
            fi
        fi
    done

    # Clean up stale FIFOs
    rm -f "${MCP_FIFO_DIR}"/*.fifo 2>/dev/null || true

    success "Cleanup complete"
}

# Test a server by sending a simple message
test_server() {
    local server_name="$1"
    local fifo="${MCP_FIFO_DIR}/${server_name}.fifo"

    if ! is_running "$server_name"; then
        error "$server_name is not running"
        return 1
    fi

    if [[ ! -p "$fifo" ]]; then
        error "FIFO not found for $server_name"
        return 1
    fi

    log "Testing $server_name..."

    # Send a simple initialize request
    echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' > "$fifo"

    sleep 1

    log "Test message sent. Check logs for response:"
    tail -n 20 "${MCP_LOG_DIR}/${server_name}.log"
}

# List available servers
list_servers() {
    echo ""
    echo "Available MCP Servers:"
    echo "======================"
    for server_name in "${!MCP_SERVERS[@]}"; do
        echo "  - $server_name"
    done
    echo ""
}

# Main command dispatcher
case "${1:-}" in
    start)
        if [[ -n "${2:-}" ]]; then
            start_server "$2"
        else
            start_all
        fi
        ;;

    stop)
        if [[ -n "${2:-}" ]]; then
            stop_server "$2"
        else
            stop_all
        fi
        ;;

    restart)
        if [[ -n "${2:-}" ]]; then
            stop_server "$2"
            sleep 1
            start_server "$2"
        else
            restart_all
        fi
        ;;

    status)
        if [[ -n "${2:-}" ]]; then
            status_server "$2"
        else
            status_all
        fi
        ;;

    logs)
        if [[ -z "${2:-}" ]]; then
            error "Usage: $0 logs <server-name>"
            exit 1
        fi
        logs "$2"
        ;;

    follow)
        if [[ -z "${2:-}" ]]; then
            error "Usage: $0 follow <server-name>"
            exit 1
        fi
        follow_logs "$2"
        ;;

    test)
        if [[ -z "${2:-}" ]]; then
            error "Usage: $0 test <server-name>"
            exit 1
        fi
        test_server "$2"
        ;;

    cleanup)
        cleanup
        ;;

    list)
        list_servers
        ;;

    *)
        echo "MCP Server Manager - Background Server Management Tool"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|follow|test|cleanup|list} [server-name]"
        echo ""
        echo "Commands:"
        echo "  start [server]    - Start all servers or a specific server"
        echo "  stop [server]     - Stop all servers or a specific server"
        echo "  restart [server]  - Restart all servers or a specific server"
        echo "  status [server]   - Show status of all or specific server"
        echo "  logs <server>     - Show logs for a specific server"
        echo "  follow <server>   - Follow logs in real-time"
        echo "  test <server>     - Test server by sending a message"
        echo "  cleanup           - Clean up orphaned processes and stale files"
        echo "  list              - List all available servers"
        echo ""
        list_servers
        exit 1
        ;;
esac
