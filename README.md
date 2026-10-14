# Progress Tracker for macOS

A native SwiftUI productivity app with a live progress dashboard, project breakdowns, priorities, due dates, and a daily calendar. It includes day and dark themes plus circular and segmented progress formats. Tasks and events are kept separate and saved locally in `~/Library/Application Support/ProgressTracker/`.

## Run during development

No third-party dependencies are required. On macOS with Swift installed:

```bash
swift run
```

## Build a local `.app`

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open "dist/Progress Tracker.app"
```

You can drag `dist/Progress Tracker.app` into your **Applications** folder. The script applies an ad-hoc signature, which is intended for running on your own Mac.

If macOS blocks the first launch, right-click the app, choose **Open**, then choose **Open** again.

## App icon

The app ships with a brand icon in `Resources/` — the lime-to-teal accent gradient on a rounded squircle with the checkmark that stands for completed progress, matching the in-app header. `build-app.sh` copies `Resources/AppIcon.icns` into the bundle so it appears in the Dock and Finder.

The icon is generated from a single source so it can be rebuilt on any platform (only [Pillow](https://pypi.org/project/Pillow/) is required, no macOS-only tools):

```bash
python3 scripts/generate-icon.py
```

`Resources/AppIcon.svg` is the editable vector source of the same mark.

## Let a bot access tasks with MCP

The included MCP server gives a bot tools to manage tasks, projects, priorities, due dates, calendar events, and Focus mode. Focus tools can read status, choose a duration, start, pause, resume, or reset the timer while keeping the app synchronized.

### Local MCP clients (Pi, Claude Desktop, etc.)

The project includes `.pi/mcp.json`. From this directory, run `pi mcp list` to verify the connection. For another local MCP client, configure a stdio server with:

```json
{
  "command": "node",
  "args": ["/absolute/path/to/progress-tracker/mcp-server/index.js"]
}
```

### Internet access using Cloudflare Tunnel

This option is useful for a hosted bot that requires an HTTPS URL. Keep the generated API key private.

```bash
brew install cloudflared   # only needed once
chmod +x scripts/start-public-mcp.sh scripts/stop-public-mcp.sh
./scripts/start-public-mcp.sh
```

Give the bot the printed HTTPS `/mcp` URL and select **API key / Bearer token** authentication. Your Mac must stay awake and online. A quick-tunnel URL changes whenever you restart it.

Stop public access with:

```bash
./scripts/stop-public-mcp.sh
```

The app checks for bot changes every second, so remotely added or organized tasks appear automatically.

## Share or publish later

To distribute outside your own Mac, enroll in the Apple Developer Program, sign with a **Developer ID Application** certificate, enable the hardened runtime, submit the app to Apple's notarization service, and staple the notarization ticket. For the Mac App Store, create an Xcode project and follow App Store Connect's signing and submission flow.
