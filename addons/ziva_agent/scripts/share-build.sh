#!/bin/sh
# POSIX wrapper for Godot Web export (Linux + macOS). On first run (templates
# missing) it downloads + unpacks the .tpz from the upstream Godot release,
# then invokes the Godot binary --headless to produce the .html/.js/.wasm/.pck
# bundle.
#
# Communicates with the editor via three files in the output dir:
#   state.json     atomic write per phase, polled by the JS store
#   manifest.json  written once after Godot succeeds
#   export.exit    integer exit code, written last
# export.log is for humans only.

set -u

LOG_PATH=""
EXIT_FILE=""
OUTPUT_DIR=""
WEB_TPL=""
TPL_DIR=""
TPZ_PATH=""
TPZ_EXTRACT_DIR=""
URL=""
GODOT_BIN=""
INDEX_HTML=""
PROJECT_PATH=""
STATE_FILE=""
MANIFEST_FILE=""

usage() {
    echo "Usage: $0 --log-path P --exit-file P --output-dir P --web-tpl P --tpl-dir P --tpz-path P --tpz-extract-dir P --url U --godot-bin P --index-html P --project-path P --state-file P --manifest-file P" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --log-path) LOG_PATH="$2"; shift 2 ;;
        --exit-file) EXIT_FILE="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --web-tpl) WEB_TPL="$2"; shift 2 ;;
        --tpl-dir) TPL_DIR="$2"; shift 2 ;;
        --tpz-path) TPZ_PATH="$2"; shift 2 ;;
        --tpz-extract-dir) TPZ_EXTRACT_DIR="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --godot-bin) GODOT_BIN="$2"; shift 2 ;;
        --index-html) INDEX_HTML="$2"; shift 2 ;;
        --project-path) PROJECT_PATH="$2"; shift 2 ;;
        --state-file) STATE_FILE="$2"; shift 2 ;;
        --manifest-file) MANIFEST_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
done

required_vars="LOG_PATH EXIT_FILE OUTPUT_DIR WEB_TPL TPL_DIR TPZ_PATH TPZ_EXTRACT_DIR URL GODOT_BIN INDEX_HTML PROJECT_PATH STATE_FILE MANIFEST_FILE"
for var in $required_vars; do
    eval "val=\${$var:-}"
    if [ -z "$val" ]; then
        echo "Missing required flag for $var" >&2
        usage
        exit 2
    fi
done

# Escape a string for embedding in a JSON string literal. Filenames in our
# output dir are produced by Godot's web export (.html/.js/.wasm/.pck) and
# stick to ASCII, so escaping \ and " is sufficient.
json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

iso_now() {
    # POSIX date doesn't have %N, so we approximate ms with .000.
    date -u +'%Y-%m-%dT%H:%M:%S.000Z'
}

# Atomic state writer. Build JSON manually (jq is not guaranteed); progress
# and error are emitted as null when their args are empty.
write_state() {
    phase="$1"
    bytes_done="${2:-}"
    bytes_total="${3:-}"
    err_msg="${4:-}"

    if [ -n "$bytes_done" ] && [ -n "$bytes_total" ]; then
        progress="{\"bytesDone\":${bytes_done},\"bytesTotal\":${bytes_total}}"
    else
        progress="null"
    fi

    if [ -n "$err_msg" ]; then
        err_field="\"$(json_escape "$err_msg")\""
    else
        err_field="null"
    fi

    json="{\"phase\":\"${phase}\",\"progress\":${progress},\"error\":${err_field},\"updatedAt\":\"$(iso_now)\"}"
    printf '%s' "$json" > "${STATE_FILE}.tmp" && mv -f "${STATE_FILE}.tmp" "$STATE_FILE"
}

# Manifest writer for the export output directory.
write_manifest() {
    manifest_entries=""
    first=1
    for fpath in "$OUTPUT_DIR"/*; do
        [ -f "$fpath" ] || continue
        fname=$(basename "$fpath")
        case "$fname" in
            export.log|export.exit|state.json|manifest.json|templates.tpz) continue ;;
        esac
        fsize=$(wc -c < "$fpath" | tr -d ' ')
        escaped_name=$(json_escape "$fname")
        if [ $first -eq 1 ]; then
            first=0
        else
            manifest_entries="${manifest_entries},"
        fi
        manifest_entries="${manifest_entries}{\"name\":\"${escaped_name}\",\"sizeBytes\":${fsize}}"
    done
    manifest_json="{\"files\":[${manifest_entries}]}"
    printf '%s' "$manifest_json" > "${MANIFEST_FILE}.tmp" || return 1
    mv -f "${MANIFEST_FILE}.tmp" "$MANIFEST_FILE"
}

# Setup block runs only on first export — subsequent runs skip the download
# since web_release.zip is present.
if [ ! -f "$WEB_TPL" ]; then
    echo 'Downloading Godot export templates (~750MB, one-time setup)...' >> "$LOG_PATH"
    write_state "download"
    if ! mkdir -p "$TPL_DIR" >> "$LOG_PATH" 2>&1; then
        write_state "failed" "" "" "Failed to create templates dir: $TPL_DIR"
        echo 90 > "$EXIT_FILE"
        exit 90
    fi
    if ! curl -fL --progress-bar "$URL" -o "$TPZ_PATH" >> "$LOG_PATH" 2>&1; then
        write_state "failed" "" "" "curl failed downloading $URL"
        echo 90 > "$EXIT_FILE"
        exit 90
    fi
    write_state "extract"
    echo 'Extracting templates...' >> "$LOG_PATH"
    if ! mkdir -p "$TPZ_EXTRACT_DIR" >> "$LOG_PATH" 2>&1; then
        write_state "failed" "" "" "Failed to create extract dir"
        echo 90 > "$EXIT_FILE"
        exit 90
    fi
    if ! unzip -q "$TPZ_PATH" -d "$TPZ_EXTRACT_DIR" >> "$LOG_PATH" 2>&1; then
        write_state "failed" "" "" "unzip failed"
        echo 90 > "$EXIT_FILE"
        exit 90
    fi
    if ! cp -r "$TPZ_EXTRACT_DIR/templates/." "$TPL_DIR/" >> "$LOG_PATH" 2>&1; then
        write_state "failed" "" "" "cp templates failed"
        echo 90 > "$EXIT_FILE"
        exit 90
    fi
    rm -rf "$TPZ_EXTRACT_DIR" "$TPZ_PATH"
    write_state "installing"
    echo 'Templates installed.' >> "$LOG_PATH"
fi

if [ ! -f "$WEB_TPL" ]; then
    echo 'Failed to install Godot Web export templates' >> "$LOG_PATH"
    write_state "failed" "" "" "Failed to install Godot Web export templates"
    echo 90 > "$EXIT_FILE"
    exit 90
fi

write_state "exporting"
echo 'Starting Godot export...' >> "$LOG_PATH"
"$GODOT_BIN" --headless --export-release Web "$INDEX_HTML" --path "$PROJECT_PATH" >> "$LOG_PATH" 2>&1
godot_exit=$?

if [ "$godot_exit" -ne 0 ]; then
    write_state "failed" "" "" "Godot export exited with code ${godot_exit}"
    echo "$godot_exit" > "$EXIT_FILE"
    exit "$godot_exit"
fi

write_state "verifying"

# Cross-process FS visibility race: index.html may not be visible to the
# editor process immediately after Godot exits. Wait up to 15 s.
deadline=$(( $(date +%s) + 15 ))
while [ ! -f "$INDEX_HTML" ] && [ "$(date +%s)" -lt "$deadline" ]; do
    sleep 0.2
done

if [ ! -f "$INDEX_HTML" ]; then
    msg="index.html not produced after 15s wait: $INDEX_HTML"
    echo "$msg" >> "$LOG_PATH"
    write_state "failed" "" "" "$msg"
    echo 91 > "$EXIT_FILE"
    exit 91
fi

# Enumerate output files for the manifest via the shared writer.
if ! write_manifest; then
    write_state "failed" "" "" "Manifest write failed"
    echo 92 > "$EXIT_FILE"
    exit 92
fi

write_state "done"
echo 0 > "$EXIT_FILE"
exit 0
