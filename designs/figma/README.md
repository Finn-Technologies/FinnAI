# Flux Figma export

This directory is the project-local input for `figma-local-mcp`.

1. Open the Flux file in the Figma desktop app.
2. Run **Framelink Exporter**.
3. Select the production frames and leave PNG renders, SVG icons, and image fills enabled.
4. Export the ZIP and extract its JSON file and `.assets` directory here.

After exporting, reference the JSON with an absolute path, for example:

`/Users/abhi/Desktop/FinnAI/designs/figma/flux-app.json`

The local MCP server is registered in Codex as `figma-local` and exposes
`get_figma_data_from_json`, `get_node_image`, and `get_node_svg`.
