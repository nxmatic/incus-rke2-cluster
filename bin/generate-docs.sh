#!/bin/bash
# generate-docs.sh - Generate HTML documentation from AsciiDoc sources

set -euo pipefail

# Check if asciidoctor is available
if ! command -v asciidoctor &> /dev/null; then
    echo "Error: asciidoctor not found. Suggested options:"
    echo "  1) nix develop .#docs   # enter docs dev shell (flake devShell)"
    echo "  2) nix shell nixpkgs#asciidoctor-with-extensions nixpkgs#plantuml nixpkgs#graphviz"
    echo "  3) (alt) gem install asciidoctor asciidoctor-diagram plantuml-ruby"
    exit 1
fi

# Diagram backend detection / override logic
# Force local diagram generation with: FORCE_DIAGRAM=1 ./bin/generate-docs.sh
if [ "${FORCE_DIAGRAM:-}" = "1" ]; then
    DOCS_DIAGRAM_BACKEND="diagram"
fi

if [ -z "${DOCS_DIAGRAM_BACKEND:-}" ]; then
    # Try explicit require first
    if asciidoctor -r asciidoctor-diagram -v >/dev/null 2>&1; then
        DOCS_DIAGRAM_BACKEND="diagram"
    else
        # Functional probe: render a minimal PlantUML block asking Asciidoctor to load the extension inline.
        tmpdir="$(mktemp -d 2>/dev/null || mktemp -d -t docsprobe)"
        cat >"$tmpdir/probe.adoc" <<'EOF'
:require-asciidoctor-diagram:
[plantuml,probe,svg]
----
@startuml
Alice -> Bob: Hi
@enduml
----
EOF
        asciidoctor -r asciidoctor-diagram "$tmpdir/probe.adoc" >/dev/null 2>&1 || true
        if grep -q '<svg' "$tmpdir/probe.html" 2>/dev/null; then
            DOCS_DIAGRAM_BACKEND="diagram"
        else
            echo "Warning: diagram extension not active; using Kroki remote rendering."
            DOCS_DIAGRAM_BACKEND="kroki"
        fi
        rm -rf "$tmpdir"
    fi
fi

# Ensure Graphviz (dot) availability for local PlantUML rendering
if [ "$DOCS_DIAGRAM_BACKEND" = "diagram" ]; then
    if command -v dot >/dev/null 2>&1; then
        export GRAPHVIZ_DOT="$(command -v dot)"
    else
        echo "Graphviz 'dot' not found; diagrams requiring dot will be rendered via Kroki."
        # Only flip to Kroki if PlantUML needs dot (most diagrams do); keep existing decision otherwise.
        [ "$DOCS_DIAGRAM_BACKEND" = "diagram" ] && DOCS_DIAGRAM_BACKEND="kroki"
    fi
fi

# Optional: verify PlantUML can see dot when in local mode
if [ "$DOCS_DIAGRAM_BACKEND" = "diagram" ] && command -v plantuml >/dev/null 2>&1; then
    if ! plantuml -testdot >/dev/null 2>&1; then
        echo "PlantUML -testdot could not validate Graphviz; switching to Kroki for reliability."
        DOCS_DIAGRAM_BACKEND="kroki"
    fi
fi

# Change to docs directory
cd docs

echo "Generating HTML documentation..."

# Generate all AsciiDoc files
for file in *.adoc; do
    echo "  Processing: $file"
    if [ "$DOCS_DIAGRAM_BACKEND" = "diagram" ]; then
        asciidoctor \
          -r asciidoctor-diagram \
          -a source-highlighter=rouge \
          -a icons=font \
          -a sectlinks \
          -a sectanchors \
          -a toc=left \
          -a toclevels=3 \
          -a plantuml-format=svg \
          -a diagram-on-error=abort \
          -a imagesdir=images \
          "$file"
    else
                asciidoctor \
          -a source-highlighter=rouge \
          -a icons=font \
          -a sectlinks \
          -a sectanchors \
          -a toc=left \
          -a toclevels=3 \
          -a plantuml-format=svg \
          -a kroki-server-url=https://kroki.io \
          -a kroki-fetch-diagram \
          -a imagesdir=images \
          "$file"
    fi
done

if [ "$DOCS_DIAGRAM_BACKEND" = "diagram" ]; then
    echo "Diagram cache contents (if any):"
    ls -1 .asciidoctor/diagram 2>/dev/null || echo "(no diagram cache yet)"
else
    echo "(Kroki fallback mode - no local diagram cache)"
fi

echo "Documentation generated successfully!"
echo "Open docs/README.html in your browser to view the main index."
echo ""
echo "Generated files:"
ls -la *.html