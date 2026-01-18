#!/bin/bash
# Build static HTML export of the presentation

set -e

OUTPUT_DIR="_site"

echo "Building static HTML to $OUTPUT_DIR/..."
reveal-md operator-presentation.md --static "$OUTPUT_DIR" --css kubernetes-theme.css

# Copy images
cp -r images "$OUTPUT_DIR/"

echo ""
echo "Done! Open $OUTPUT_DIR/operator-presentation.html in a browser."
