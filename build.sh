#!/bin/bash
# Build static HTML export of presentations

set -e

OUTPUT_DIR="_site"

PRESENTATIONS=(
    "operator-presentation.md"
    "crd-design.md"
    "testing-operators.md"
    "debugging-operators.md"
    "admission-webhooks.md"
)

build_one() {
    local file="$1"
    local name="${file%.md}"
    echo "Building $file..."
    reveal-md "$file" --static "$OUTPUT_DIR" --css kubernetes-theme.css
    echo "  -> $OUTPUT_DIR/$name.html"
}

build_all() {
    echo "Building all presentations to $OUTPUT_DIR/..."
    echo ""
    for file in "${PRESENTATIONS[@]}"; do
        if [[ -f "$file" ]]; then
            build_one "$file"
        else
            echo "Skipping $file (not found)"
        fi
    done
}

# Parse arguments
if [[ "$1" == "all" || -z "$1" ]]; then
    build_all
else
    case "$1" in
        1|operator) FILE="operator-presentation.md" ;;
        2|crd) FILE="crd-design.md" ;;
        3|testing) FILE="testing-operators.md" ;;
        4|debugging) FILE="debugging-operators.md" ;;
        5|webhooks) FILE="admission-webhooks.md" ;;
        *.md) FILE="$1" ;;
        *)
            echo "Usage: $0 [all|operator|crd|testing|debugging|webhooks|<file.md>]"
            exit 1
            ;;
    esac

    if [[ ! -f "$FILE" ]]; then
        echo "Error: $FILE not found"
        exit 1
    fi

    echo "Building $FILE to $OUTPUT_DIR/..."
    build_one "$FILE"
fi

# Copy images if directory exists
if [[ -d "images" ]]; then
    cp -r images "$OUTPUT_DIR/"
fi

echo ""
echo "Done! Open files in $OUTPUT_DIR/ in a browser."
