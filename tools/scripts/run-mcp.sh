#!/bin/bash
# Run the purplestack MCP server
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
(fvm flutter pub get || flutter pub get) && fvm dart run "$SCRIPT_DIR/purplestack_mcp.dart"