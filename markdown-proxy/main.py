"""
Markdown Stripper Proxy for LLM responses.

Strips markdown code blocks from OpenAI-compatible API responses.
Hindsight → This Proxy (8318) → CLIProxyAPI (8317)
"""

import re
import json
import httpx
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse
import uvicorn

app = FastAPI(title="Markdown Stripper Proxy", version="1.0.0")

# Configuration
UPSTREAM_URL = "http://localhost:8317"
PROXY_PORT = 8318


def strip_markdown_json(text: str) -> str:
    """
    Strip markdown code blocks from JSON responses.

    Handles:
    - ```json\n{...}\n```
    - ```\n{...}\n```
    - Nested or multiple code blocks
    """
    if not text:
        return text

    # Pattern for JSON code blocks
    patterns = [
        r'```json\s*\n?(.*?)\n?```',  # ```json ... ```
        r'```\s*\n?(.*?)\n?```',       # ``` ... ```
    ]

    result = text
    for pattern in patterns:
        match = re.search(pattern, result, re.DOTALL)
        if match:
            result = match.group(1).strip()
            break

    return result


def process_openai_response(response_data: dict) -> dict:
    """Process OpenAI-compatible response and strip markdown from content."""
    if "choices" not in response_data:
        return response_data

    for choice in response_data.get("choices", []):
        message = choice.get("message", {})
        content = message.get("content", "")

        if content:
            stripped = strip_markdown_json(content)
            # Only update if we actually stripped something and result is valid JSON
            if stripped != content:
                try:
                    # Validate it's valid JSON
                    json.loads(stripped)
                    message["content"] = stripped
                except json.JSONDecodeError:
                    # Keep original if stripped version isn't valid JSON
                    pass

    return response_data


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy", "upstream": UPSTREAM_URL}


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(request: Request, path: str):
    """Proxy all requests to upstream, stripping markdown from responses."""

    # Build upstream URL
    upstream_url = f"{UPSTREAM_URL}/{path}"
    if request.query_params:
        upstream_url += f"?{request.query_params}"

    # Get request body
    body = await request.body()

    # Forward request
    async with httpx.AsyncClient(timeout=120.0) as client:
        upstream_response = await client.request(
            method=request.method,
            url=upstream_url,
            headers={k: v for k, v in request.headers.items()
                    if k.lower() not in ("host", "content-length")},
            content=body,
        )

    # Process response if it's a chat completion
    content_type = upstream_response.headers.get("content-type", "")

    if "application/json" in content_type and path.endswith("chat/completions"):
        try:
            response_data = upstream_response.json()
            processed = process_openai_response(response_data)
            return Response(
                content=json.dumps(processed),
                status_code=upstream_response.status_code,
                media_type="application/json"
            )
        except Exception:
            pass

    # Return original response for non-chat endpoints
    # Filter out problematic headers
    filtered_headers = {
        k: v for k, v in upstream_response.headers.items()
        if k.lower() not in ("content-length", "content-encoding", "transfer-encoding")
    }
    return Response(
        content=upstream_response.content,
        status_code=upstream_response.status_code,
        headers=filtered_headers,
    )


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PROXY_PORT)
