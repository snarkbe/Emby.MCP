# Emby.MCP

MCP server that connects an Emby media server to any MCP-compatible AI client (Claude, VS Code Copilot, etc.).

> **Fork** of [angeltek/Emby.MCP](https://github.com/angeltek/Emby.MCP) — adds a read-only mode flag.

**Not affiliated with or endorsed by [Emby LLC](https://emby.media/).**

## Features

- Browse media libraries, genres, and items (search by title, artist, album, year, lyrics)
- List and manage playlists (create, edit, reorder, share)
- List and manage collections (create, add/remove items, delete)
- Control media players (play, pause, seek, queue)
- Read-only mode: disable all write operations via a single env var
- Chunked search results to stay within LLM context limits

## Requirements

- Python 3.13+
- [uv](https://docs.astral.sh/uv/) package manager
- [MCP Server SDK for Python](https://github.com/modelcontextprotocol/python-sdk/) v2.0+
- [Emby client SDK](https://pypi.org/project/embyclient/) v4.9.0.33 (+ a hotfix patch, see below)
- A running [Emby Media Server](https://emby.media/about.html)
- An MCP-compatible AI client that supports **Tools**

## Installation

```bash
# 1. Clone and install dependencies
git clone https://github.com/snarkbe/Emby.MCP.git
cd Emby.MCP
uv sync --link-mode=copy

# 2. Apply the Emby SDK hotfix (repeat after every uv sync)
# The shipped SDK is missing the ItemId parameter on /Users/ItemAccess,
# which is required by the playlist sharing query.
# Windows:
copy "hotfixes\emby\user_service_api.py" ".venv\Lib\site-packages\emby_client\api"
# Linux/macOS:
cp hotfixes/emby/user_service_api.py .venv/lib/python*/site-packages/emby_client/api/
```

## Configuration

Create a `.env` file in the project directory:

```env
EMBY_SERVER_URL = "http://localhost:8096"
EMBY_USERNAME   = "user"
EMBY_API_KEY    = "your-api-key"   # Emby admin -> Advanced -> API Keys -> New API Key

# Optional
EMBY_VERIFY_SSL = True   # Set False to skip SSL cert verification (e.g. self-signed). Default: True
EMBY_READONLY   = False  # Set True to expose only read/query tools — disables playlist write and player control. Default: False
LLM_MAX_ITEMS   = 100    # Max items per search chunk (0 = no limit). Default: 100
```

> Tip: create a dedicated Emby user for Emby.MCP to limit its access. The username is still required to resolve which user_id the tools act as.

### Verify the setup

```bash
uv run emby_mcp_server.py
# Should log in and list libraries, then start the MCP server on stdio. Press Ctrl-C to exit.
```

## Client Setup

### Claude Desktop

Edit `%USERPROFILE%\AppData\Roaming\Claude\claude_desktop_config.json` (Windows) or `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS):

```json
{
  "mcpServers": {
    "Emby": {
      "command": "uv",
      "args": ["run", "--directory", "/path/to/Emby.MCP", "--with", "embyclient", "--with", "mcp[cli]", "mcp", "run", "emby_mcp_server.py"]
    }
  }
}
```

Restart Claude Desktop. On first use, approve each tool when prompted (select **Allow always**).

### Docker

Build the image:

```bash
docker build -t emby-mcp .
```

Configuration is supplied entirely via environment variables — **no `.env` file is
copied into the image**. Pass `EMBY_SERVER_URL`, `EMBY_USERNAME`, `EMBY_API_KEY` (required)
and optionally `EMBY_VERIFY_SSL`, `EMBY_READONLY`, `LLM_MAX_ITEMS` with `-e` or `--env-file`:

```bash
docker run --rm -i \
  -e EMBY_SERVER_URL=http://your-emby-host:8096 \
  -e EMBY_USERNAME=user \
  -e EMBY_API_KEY=your-api-key \
  emby-mcp
```

The server communicates over stdio, so an MCP client spawns `docker run -i ...` as its
command. For Claude Desktop / VS Code Copilot, use an `--env-file` to keep secrets out of
the client config (create a local `docker.env` file, listed in `.gitignore`, with the
same `KEY=value` lines as `.env`):

```json
{
  "mcpServers": {
    "Emby": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--env-file", "/path/to/docker.env", "emby-mcp"]
    }
  }
}
```

### VS Code Copilot

Add to your `mcp.json` (see [VS Code docs](https://code.visualstudio.com/docs/copilot/chat/mcp-servers)):

```json
{
  "servers": {
    "Emby": {
      "command": "uv",
      "args": ["run", "--directory", "/path/to/Emby.MCP", "--with", "embyclient", "--with", "mcp[cli]", "mcp", "run", "emby_mcp_server.py"]
    }
  }
}
```

## Usage

Start a conversation by mentioning Emby to hint which tools to use:

```
list emby libraries
→ select music library
→ find jazz albums from the 1960s
→ create a playlist called "60s Jazz" and add the top 10 results
```

Tips:
- Select a library early to narrow results.
- Be explicit when searching by **lyrics** or **description**, otherwise the LLM defaults to title/artist search.
- If results are truncated, ask the LLM to fetch the next chunk.

## Read-only Mode

Set `EMBY_READONLY = True` in `.env` to prevent the LLM from modifying anything. The following tools are hidden from the MCP client in this mode:

| Tool | Action |
|---|---|
| `create_playlist` | Creates a playlist |
| `modify_playlist_name` | Renames / redescribes a playlist |
| `add_items_to_playlist` | Adds items to a playlist |
| `remove_items_from_playlist` | Removes items from a playlist |
| `reorder_items_on_playlist` | Moves an item within a playlist |
| `share_playlist_public` | Shares a playlist with all users |
| `share_playlist_user_access` | Grants per-user playlist access |
| `stop_sharing_playlist` | Stops sharing a playlist |
| `create_collection` | Creates a collection |
| `add_items_to_collection` | Adds items to a collection |
| `remove_items_from_collection` | Removes items from a collection |
| `delete_collection` | Deletes a collection |
| `control_media_player` | Sends commands to a player |

## License

GPL v3, © 2025 Dominic Search <code@angeltek.co.uk>, modified 2026 by Gilles Reichert — see [LICENSE.txt](LICENSE.txt).
