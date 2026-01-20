# Maxwell Popup (macOS)

Floating Maxwell GIF that stays on top of all windows.

## Build

```bash
swift build -c release
```

## Run

```bash
./run.sh
# or
./.build/release/maxwell-popup
```

## Alias

Add to `~/.zshrc`:
```bash
alias maxwell="/path/to/maxwell-popup/.build/release/maxwell-popup &"
```

## Usage

- **Drag** anywhere to move
- **Hover** to reveal buttons:
  - `−` shrink
  - `+` grow
  - `✕` close

## Auto-start on Login

```bash
# Disable
launchctl unload ~/Library/LaunchAgents/com.maxwell.popup.plist

# Enable
launchctl load ~/Library/LaunchAgents/com.maxwell.popup.plist

# Remove completely
rm ~/Library/LaunchAgents/com.maxwell.popup.plist
```
