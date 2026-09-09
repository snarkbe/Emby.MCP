# syntax=docker/dockerfile:1
FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project --no-dev

# Apply the Emby SDK hotfix (adds the ItemId parameter to /Users/ItemAccess, which
# retrieve_playlist_list / get_playlists() requires). Must be repeated after every
# `uv sync`, same as documented for local installs in README.md.
COPY hotfixes/emby/user_service_api.py .venv/lib/python3.13/site-packages/emby_client/api/user_service_api.py

COPY emby_mcp_server.py lib_emby_functions.py ./

ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1

# Run as a non-root user. No secrets are baked into the image: EMBY_SERVER_URL,
# EMBY_USERNAME, EMBY_API_KEY (and optional EMBY_VERIFY_SSL, EMBY_READONLY,
# LLM_MAX_ITEMS) must be supplied at runtime via `docker run -e ...` / `--env-file`,
# never via a .env file baked into the image.
RUN useradd --create-home --uid 1000 embymcp
USER embymcp

ENTRYPOINT ["python", "emby_mcp_server.py"]
