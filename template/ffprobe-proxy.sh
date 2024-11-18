#!/bin/bash

# Hardcoded macOS FFmpeg path
MACOS_FFMPEG="/Applications/Jellyfin.app/Contents/MacOS/ffprobe"

# Environment Variables for Forward control
MACOS_USER="${MACOS_USER}"
MACOS_PASSWORD="${MACOS_PASSWORD}"
MACOS_PATH_MAP="${MACOS_PATH_MAP}"



# Debug options
CALL_ORIGINAL_ONLY=true  
ENABLE_CALL_RECORDING=true # if CALL_ORIGINAL_ONLY, will always record.


SCRIPT_DIR=$(dirname "$0")

# Path to the original Linux ffmpeg binary within the same directory
LINUX_FFMPEG="$SCRIPT_DIR/jellyfin-ffmpeg/ffmpeg"

LOG_FILE="$SCRIPT_DIR/ffprobe_calls.log"

# Function to replace paths in the command based on MACOS_PATH_MAP
replace_paths() {
    local cmd="$1"

    # Check if MACOS_PATH_MAP is set and non-empty
    if [ -n "$MACOS_PATH_MAP" ]; then
        # Split the MACOS_PATH_MAP by semicolons into individual mappings
        IFS=";" read -ra mappings <<< "$MACOS_PATH_MAP"

        # Loop through each mapping and apply the path replacement
        for mapping in "${mappings[@]}"; do
            IFS=":" read -r linux_path macos_path <<< "$mapping"
            if [ -n "$linux_path" ] && [ -n "$macos_path" ]; then
                # Replace all occurrences of linux_path with macos_path in the command
                cmd="${cmd//$linux_path/$macos_path}"
            fi
        done
    fi

    # echo "$cmd"
}

record_call() {
    local cmd="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $cmd" >> "$LOG_FILE"
}


execute_local_ffmpeg() {
    # record_call "ffmpeg $@"
    echo "Execute local: $LINUX_FFMPEG $@"
    "$LINUX_FFMPEG" "$@"
}

# Check if forwarding to macOS is available
is_forwarding_available() {
    if [ -z "$MACOS_USER" ] || [ -z "$MACOS_PASSWORD" ] || [ -z "$MACOS_PATH_MAP" ]; then
        return 1  
    fi
    return 0 
}


cmd="$@"

if [ "$CALL_ORIGINAL_ONLY" = true ] || [ "$ENABLE_CALL_RECORDING" = true ]; then
    echo "Will record call"
    record_call "$cmd"
fi


if [ "$CALL_ORIGINAL_ONLY" = true ]; then
    echo "Forwarding is diabled, calling original ffmpeg"
    execute_local_ffmpeg "$@"
    exit 0
fi

# Validate macOS environment variables
if ! is_forwarding_available; then
    echo "Missing macOS side configs in ENV, fallback to local forwarding"
    execute_local_ffmpeg "$@"
    exit 0
fi


cmd_with_mapped_paths=$(replace_paths "$cmd")
echo "Replaced command with real paths for macOS: $cmd_with_mapped_paths"

echo "Forwarding FFmpeg Command to macOS: $cmd_with_mapped_paths"
sshpass -p "$MACOS_PASSWORD" ssh -o StrictHostKeyChecking=no "$MACOS_USER@macos_host" "$MACOS_FFMPEG $cmd_with_mapped_paths" || {
    echo "Failed to forward to macOS. Falling back to local execution."
    execute_local_ffmpeg "$@"
}