#!/bin/bash
# generate-docs.sh - Generate HTML documentation from AsciiDoc sources

set -euo pipefail

# Check if asciidoctor is available
if ! command -v asciidoctor &> /dev/null; then
    echo "Error: asciidoctor not found. Install with:"
    echo "  gem install asciidoctor asciidoctor-diagram"
    exit 1
fi

# Change to docs directory
cd docs

echo "Generating HTML documentation..."

# Generate all AsciiDoc files
for file in *.adoc; do
    echo "  Processing: $file"
    asciidoctor \
        --attribute source-highlighter=rouge \
        --attribute icons=font \
        --attribute sectlinks \
        --attribute sectanchors \
        --attribute toc=left \
        --attribute toclevels=3 \
        "$file"
done

echo "Documentation generated successfully!"
echo "Open docs/README.html in your browser to view the main index."
echo ""
echo "Generated files:"
ls -la *.html