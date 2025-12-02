# Notification Hook Plugin

A Claude Code hook that plays a sound notification whenever Claude sends notifications.

## Features

- Plays a pleasant chime sound when Claude sends notifications
- Non-blocking audio playback (doesn't interrupt your workflow)
- Easy to install and configure
- Uses Python's playsound3 library for cross-platform compatibility

## Prerequisites

- Python 3.6 or higher
- pip (Python package installer)

## Installation

### 1. Install the Plugin

Copy the plugin to your Claude Code plugins directory:

```bash
cp -r plugins/notification-hook ~/.claude/plugins/
```

### 2. Set Up Python Virtual Environment

Create a dedicated virtual environment for the hook:

```bash
# Create virtual environment (you can place it anywhere you prefer)
python3 -m venv ~/claude-venv

# Activate the virtual environment
source ~/claude-venv/bin/activate

# Install the required playsound3 library
pip install playsound3==3.3.0

# Deactivate the virtual environment
deactivate
```

**Note**: Remember the path to your virtual environment's Python binary. You'll need it in the next step.
For the above example, it would be: `~/claude-venv/bin/python`

### 3. Configure the Hook in Claude Code Settings

Add the notification hook to your Claude Code settings file (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-venv/bin/python ~/.claude/plugins/notification-hook/hooks/notification_hook.py"
          }
        ]
      }
    ]
  }
}
```

**Important**: Replace `~/claude-venv/bin/python` with the actual path to your Python virtual environment's binary if you created it in a different location.

### 4. Grant Permissions (if needed)

You may need to grant permissions for the hook to run. Add this to `~/.claude/settings.local.json`:

```json
{
  "permissions": {
    "hooks": {
      "allowedCommands": [
        {
          "command": "~/claude-venv/bin/python ~/.claude/plugins/notification-hook/hooks/notification_hook.py",
          "allow": true
        }
      ]
    }
  }
}
```

## How It Works

When Claude Code sends a notification:
1. The hook is triggered automatically
2. The Python script (`notification_hook.py`) is executed using the virtual environment's Python interpreter
3. The script plays the chime sound (`chime.wav`) in non-blocking mode
4. You hear a pleasant notification sound without interrupting your workflow

## File Structure

```
notification-hook/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── hooks/
│   └── notification_hook.py # Python script that plays the sound
├── assets/
│   └── chime.wav           # Audio file (RIFF WAVE, stereo 44100 Hz)
└── README.md               # This file
```

## Customization

### Using a Different Sound

Replace `assets/chime.wav` with your own audio file. The script supports WAV and MP3 formats.

### Adjusting Volume

The playsound3 library plays audio at system volume. Adjust your system volume settings to control the notification sound level.

## Troubleshooting

### Sound doesn't play

1. **Check Python path**: Ensure the path to Python in your hook command is correct
2. **Verify installation**: Make sure playsound3 is installed in your virtual environment:
   ```bash
   ~/claude-venv/bin/python -c "import playsound3; print(playsound3.__version__)"
   ```
3. **Check audio file**: Verify the chime.wav file exists at `~/.claude/plugins/notification-hook/assets/chime.wav`
4. **System permissions**: Ensure Claude Code has permission to execute the Python script

### Permission errors

Add the hook command to your allowed commands list in `~/.claude/settings.local.json` (see step 4 above).

### Dependencies not found

Ensure you're using the Python interpreter from the virtual environment where playsound3 is installed, not the system Python.

## Dependencies

- **playsound3** (version 3.3.0): Cross-platform library for playing audio files

## Platform Support

This plugin has been tested on:
- macOS (primary)
- Linux (should work with appropriate audio drivers)
- Windows (should work with appropriate audio drivers)

## License

This plugin is provided as-is for use with Claude Code.
