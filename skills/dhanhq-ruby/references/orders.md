# Orders with agents

1. Search or otherwise verify the instrument.
2. Build order params using Dhan constants and API docs.
3. Run `DhanHQ::Agent::OrderPreview.new(params).to_h`.
4. Ask the user to confirm the preview.
5. Place only if `DHANHQ_MCP_ENABLE_WRITES=true`, `LIVE_TRADING=true`, and `orders:write` scope are present.
