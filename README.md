# Emby.MCP

MCP server that connects an Emby media server to any MCP-compatible AI client (Claude, VS Code Copilot, etc.).

> **Fork** of [angeltek/Emby.MCP](https://github.com/angeltek/Emby.MCP) — adds a read-only mode flag.

**Not affiliated with or endorsed by [Emby LLC](https://emby.media/).**

## Features

- Browse media libraries, genres, and items (search by title, artist, album, year, lyrics)
- List and manage playlists (create, edit, reorder, share)
- List and manage collections (create, add/remove items, delete)
- Mark items as favorite/watched and set a personal like/dislike rating
- Control media players (play, pause, seek, queue)
- Server & library maintenance: server info, scheduled tasks, library scan, item metadata refresh
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

> Note: a few tools require that user to be an Emby administrator — see the "Requires Emby admin" column in [Available Tools](#available-tools) below. Without the required rights, they return an error instead of failing silently.

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

## Available Tools

| Category | Tool | Description | Available in read-only mode | Requires Emby admin |
|---|---|---|---|---|
| Users | `retrieve_user_list` | Lists Emby users and their user IDs | Yes | No |
| Library | `retrieve_library_list` | Lists libraries on the Emby server | Yes | No |
| Library | `select_library` | Selects the active library for subsequent tools | Yes | No |
| Library | `retrieve_current_library` | Shows the currently selected library | Yes | No |
| Genre | `retrieve_genre_list` | Lists genres available in the current library | Yes | No |
| Item search | `search_for_item` | Searches media items by title/album, artist, genre, year, lyrics | Yes | No |
| Item search | `retrieve_next_search_chunk` | Retrieves the next chunk of search results | Yes | No |
| Item state | `set_item_favorite` | Marks/unmarks an item as a favorite | No | No |
| Item state | `set_item_watched` | Marks an item as watched/unwatched | No | No |
| Item state | `rate_item` | Sets/clears your like/dislike rating for an item | No | No |
| Playlist | `create_playlist` | Creates a playlist | No | No |
| Playlist | `modify_playlist_name` | Renames / redescribes a playlist | No | No |
| Playlist | `retrieve_playlist_list` | Lists playlists | Yes | No |
| Playlist | `retrieve_playlist_items` | Lists items on a playlist | Yes | No |
| Playlist | `add_items_to_playlist` | Adds items to a playlist | No | No |
| Playlist | `remove_items_from_playlist` | Removes items from a playlist | No | No |
| Playlist | `reorder_items_on_playlist` | Moves an item within a playlist | No | No |
| Playlist | `share_playlist_public` | Shares a playlist with all users | No | No |
| Playlist | `share_playlist_user_access` | Grants per-user playlist access | No | No |
| Playlist | `stop_sharing_playlist` | Stops sharing a playlist | No | No |
| Collection | `retrieve_collection_list` | Lists collections ('BoxSets') | Yes | No |
| Collection | `retrieve_collection_items` | Lists items directly in a collection | Yes | No |
| Collection | `create_collection` | Creates a collection | No | No |
| Collection | `add_items_to_collection` | Adds items to a collection | No | No |
| Collection | `remove_items_from_collection` | Removes items from a collection | No | No |
| Collection | `delete_collection` | Deletes a collection | No | No |
| Player | `retrieve_player_list` | Lists media player sessions | Yes | No |
| Player | `retrieve_player_queue` | Lists a player's play queue | Yes | No |
| Player | `control_media_player` | Sends commands (play, pause, seek, ...) to a player | No | No |
| Server & maintenance | `retrieve_server_info` | Shows Emby server info (version, OS, network addresses) | Yes | No |
| Server & maintenance | `retrieve_scheduled_task_list` | Lists Emby's scheduled maintenance tasks | Yes | **Yes** |
| Server & maintenance | `start_scheduled_task` | Starts a scheduled maintenance task immediately | No | **Yes** |
| Server & maintenance | `scan_library` | Starts a scan of one library, or all libraries | No | Only scanning *all* libraries (no `library_id`) |
| Server & maintenance | `refresh_item_metadata` | Refreshes metadata for a single item | No | No |

"Available in read-only mode" tools are always exposed to the MCP client; the rest are hidden when `EMBY_READONLY = True` (see below). "Requires Emby admin" tools need the account behind `EMBY_API_KEY` to be an Emby administrator; without that, they return an error instead of failing silently.

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

Set `EMBY_READONLY = True` in `.env` to prevent the LLM from modifying anything. Every tool marked "No" in the "Available in read-only mode" column of the [Available Tools](#available-tools) table above is then hidden from the MCP client — this covers all playlist, collection, item-state (favorite/watched/rating), player-control and library-maintenance write tools.

## License

GPL v3, © 2025 Dominic Search <code@angeltek.co.uk>, modified 2026 by Gilles Reichert — see [LICENSE.txt](LICENSE.txt).
