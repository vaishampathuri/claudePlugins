# MCP Launcher Wrapper Plugin

A Claude Code plugin for managing and monitoring MCP (Model Context Protocol) servers in the background with daemon support and automatic restart capabilities.

## Features

- Background execution of MCP servers with stdio protocol support
- Automatic restart on server failures (daemon mode)
- Process management (start, stop, restart, status)
- Log monitoring and viewing
- FIFO-based stdin management to prevent premature server exit
- Cleanup utilities for orphaned processes
- Fully configurable server definitions and environment variables

## Quick Start Guide

1. **Install the plugin** (if using from marketplace):
   ```bash
   # The plugin will be in your Claude plugins directory
   cd ~/.claude/plugins/mcp-launcher-wrapper
   ```

2. **Create your configuration**:
   ```bash
   cp mcp-config.template.sh mcp-config.sh
   ```

3. **Edit the configuration** with your settings:
   ```bash
   # Edit these values in mcp-config.sh
   # - MCP_SERVERS_BASE_DIR: Path to your MCP servers
   # - MCP_SERVERS: Define your server names and paths
   # - get_server_env(): Add environment variables for each server
   ```

4. **Start your MCP servers**:
   ```bash
   # Option 1: Via Claude Code
   # Just ask Claude: "Start my MCP servers"

   # Option 2: Direct script usage
   ./scripts/mcp-manager.sh start

   # Option 3: Daemon mode (auto-restart on failure)
   ./scripts/start-mcp-daemon.sh
   ```

5. **Check status**:
   ```bash
   ./scripts/mcp-manager.sh status
   ```

See detailed instructions below for full configuration options.

## Installation

1. Clone or download this plugin to your Claude Code plugins directory:
   ```bash
   cd ~/.claude/plugins
   git clone <this-repo> mcp-launcher-wrapper
   # OR copy the plugin directory manually
   ```

2. Create your configuration file:
   ```bash
   cd mcp-launcher-wrapper
   cp mcp-config.template.sh mcp-config.sh
   ```

3. Edit `mcp-config.sh` with your server paths and credentials:
   ```bash
   vim mcp-config.sh
   # or use your preferred editor
   ```

4. **Important**: Add `mcp-config.sh` to `.gitignore` to protect your credentials:
   ```bash
   echo "mcp-config.sh" >> .gitignore
   ```

## Configuration

### Basic Setup

Edit `mcp-config.sh` to configure your MCP servers:

```bash
# Base directory where your MCP servers are located
export MCP_SERVERS_BASE_DIR="${HOME}/path/to/your/mcp-servers"

# Define your MCP servers
declare -A MCP_SERVERS=(
    ["wiki-server"]="node:${MCP_SERVERS_BASE_DIR}/wiki-server/build/index.js"
    ["git-server"]="node:${MCP_SERVERS_BASE_DIR}/git-server/build/src/index.js"
    ["custom-server"]="python:${MCP_SERVERS_BASE_DIR}/custom-server/main.py"
)
```

### Environment Variables

Configure server-specific environment variables in the `get_server_env()` function:

```bash
get_server_env() {
    local server_name="$1"

    case "$server_name" in
        wiki-server)
            echo "CONFLUENCE_TOKEN=your_token_here"
            echo "CONFLUENCE_BASE_URL=https://your-instance.com"
            ;;
        git-server)
            echo "GITHUB_TOKEN=your_token_here"
            echo "GITHUB_API_URL=https://api.github.com"
            ;;
    esac
}
```

## Usage

### Via Claude Code Slash Command

Once installed, you can interact with the MCP manager through Claude Code:

```
/mcp-manager start
/mcp-manager status
/mcp-manager logs wiki-server
```

### Direct Script Usage

You can also run the scripts directly:

```bash
# Start all servers
./scripts/mcp-manager.sh start

# Start specific server
./scripts/mcp-manager.sh start wiki-server

# Check status
./scripts/mcp-manager.sh status

# View logs
./scripts/mcp-manager.sh logs wiki-server

# Follow logs in real-time
./scripts/mcp-manager.sh follow wiki-server

# Stop servers
./scripts/mcp-manager.sh stop

# Cleanup orphaned processes
./scripts/mcp-manager.sh cleanup
```

### Daemon Mode (Auto-restart)

Enable daemon mode for automatic server restart on failures:

```bash
# Start daemon (starts all servers with monitoring)
./scripts/start-mcp-daemon.sh

# Stop daemon (stops all servers and monitoring)
./scripts/stop-mcp-daemon.sh
```

The daemon monitors servers every 30 seconds and automatically restarts any that have stopped.

## Available Commands

| Command | Description |
|---------|-------------|
| `start [server]` | Start all servers or a specific server |
| `stop [server]` | Stop all servers or a specific server |
| `restart [server]` | Restart all servers or a specific server |
| `status [server]` | Show status of all or specific server |
| `logs <server>` | Show last 50 lines of logs for a server |
| `follow <server>` | Follow logs in real-time (Ctrl+C to stop) |
| `test <server>` | Test server by sending an initialize message |
| `cleanup` | Clean up orphaned processes and stale files |
| `list` | List all configured servers |

## Directory Structure

```
mcp-launcher-wrapper/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── commands/
│   └── mcp-manager.md        # Slash command definition
├── scripts/
│   ├── mcp-manager.sh        # Main management script
│   ├── start-mcp-daemon.sh   # Start daemon
│   └── stop-mcp-daemon.sh    # Stop daemon
├── mcp-config.template.sh    # Configuration template
├── mcp-config.sh             # Your config (create from template)
└── README.md                 # This file
```

## How It Works

### STDIO Protocol Management

MCP servers using the stdio protocol require an open stdin to function correctly. This plugin uses FIFO (named pipes) to keep stdin open indefinitely:

1. Creates a FIFO pipe for each server
2. Starts a "keeper" process that holds the pipe open
3. Starts the MCP server with stdin redirected from the FIFO
4. Both processes are tracked via PID files

### Process Tracking

Each server maintains:
- **PID file**: Main server process ID (`~/.claude/pids/<server>.pid`)
- **Keeper PID file**: FIFO keeper process ID (`~/.claude/pids/<server>-keeper.pid`)
- **FIFO pipe**: Named pipe for stdin (`~/.claude/fifos/<server>.fifo`)
- **Log files**: Stdout and stderr logs (`~/.claude/logs/mcp-servers/<server>.log`)

### Daemon Monitoring

When daemon mode is enabled:
1. All servers are started initially
2. Monitor process checks each server every 30 seconds
3. Automatically restarts any stopped servers
4. Logs all restart events to daemon log

## Troubleshooting

### Servers won't start

1. Check your configuration:
   ```bash
   ./scripts/mcp-manager.sh list
   ```

2. Verify server paths are correct in `mcp-config.sh`

3. Check error logs:
   ```bash
   ./scripts/mcp-manager.sh logs <server-name>
   ```

### Orphaned processes

If you have duplicate or orphaned processes:

```bash
./scripts/mcp-manager.sh cleanup
```

This will:
- Kill processes not tracked by PID files
- Remove stale PID files
- Clean up abandoned FIFO pipes

### Daemon not restarting servers

1. Check daemon is running:
   ```bash
   cat ~/.claude/pids/mcp-daemon.pid
   ps -p <pid>
   ```

2. View daemon logs:
   ```bash
   tail -f ~/.claude/logs/mcp-servers/mcp-daemon.log
   ```

### Permission issues

Ensure scripts are executable:

```bash
chmod +x scripts/*.sh
chmod +x mcp-config.sh
```

## Security Considerations

- **Keep `mcp-config.sh` private**: It contains sensitive tokens and credentials
- **Add to .gitignore**: Never commit your config file to version control
- **Use environment variables**: Consider using system environment variables instead of hardcoding credentials
- **Restrict file permissions**:
  ```bash
  chmod 600 mcp-config.sh
  ```

## Advanced Configuration

### Using System Environment Variables

Instead of hardcoding credentials in `mcp-config.sh`, you can reference system environment variables:

```bash
get_server_env() {
    local server_name="$1"

    case "$server_name" in
        wiki-server)
            echo "CONFLUENCE_TOKEN=${CONFLUENCE_TOKEN}"
            echo "CONFLUENCE_BASE_URL=${CONFLUENCE_URL}"
            ;;
    esac
}
```

Then set them in your shell profile:
```bash
export CONFLUENCE_TOKEN="your_token_here"
export CONFLUENCE_URL="https://your-instance.com"
```

### Custom Server Executables

You can use any executable as the server command:

```bash
declare -A MCP_SERVERS=(
    ["node-server"]="node:path/to/script.js"
    ["python-server"]="python3:path/to/script.py"
    ["binary-server"]="/usr/local/bin/custom-mcp-server:"
    ["deno-server"]="deno:run:--allow-all:path/to/script.ts"
)
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This plugin is provided as-is for use with Claude Code.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs for error messages
3. Open an issue in the repository

## Changelog

### Version 1.0.0
- Initial release
- Basic server management (start, stop, restart, status)
- Daemon mode with auto-restart
- Log viewing and following
- Configurable server definitions
- FIFO-based stdin management
- Cleanup utilities
