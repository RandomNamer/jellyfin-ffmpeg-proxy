#!/bin/bash

# Hardcoded macOS FFmpeg path
MACOS_FFMPEG="/Applications/Jellyfin.app/Contents/MacOS/ffmpeg"

# Environment Variables for Forward control
MACOS_USER="${MACOS_USER}"
MACOS_PASSWORD="${MACOS_PASSWORD}"
MACOS_PATH_MAP="${MACOS_PATH_MAP}"

MACOS_HOST="192.168.50.99"


# Debug options
CALL_ORIGINAL_ONLY=false  
ENABLE_CALL_RECORDING=true # if CALL_ORIGINAL_ONLY, will always record.


SCRIPT_DIR=$(dirname "$0")

# Path to the original Linux ffmpeg binary within the same directory
LINUX_FFMPEG="$SCRIPT_DIR/ffmpeg_original"

LOG_FILE="$SCRIPT_DIR/ffmpeg_calls.log"

# Below is shared logic
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

    echo "$cmd"

}

log() {
    local message="${1}"
    local level="${2:-DBG}"  
    

    # Write the log message with a timestamp and level
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
}

record_call() {
    local cmd="$1"
    log "Recorded call args: $cmd" "INF"
}



execute_local_ffmpeg() {
    # Note $@ is split into separate arguments
    log "Execute local: $LINUX_FFMPEG $*"
    "$LINUX_FFMPEG" "$@"  1>&1 2>&2
    exit $?
}

# Check if forwarding to macOS is available
is_forwarding_available() {
    # return 0
    if [ -z "$MACOS_USER" ] || [ -z "$MACOS_PASSWORD" ] || [ -z "$MACOS_PATH_MAP" ]; then
        return 1  
    fi
    return 0 
}

execute_macos_ffmpeg() {
    local args="$1"
    local macos_cmd_final="-p $MACOS_PASSWORD ssh -o StrictHostKeyChecking=no $MACOS_USER@$MACOS_HOST $MACOS_FFMPEG $args"
    # log "Forwarding FFmpeg Command to macOS: $macos_cmd_final"
    log "Forwarding FFmpeg Command to macOS: $args"

    
    sshpass -p "$MACOS_PASSWORD" ssh -o StrictHostKeyChecking=no "$MACOS_USER@$MACOS_HOST" "$MACOS_FFMPEG $args | tee -a /Users/zzy/Desktop/ffmpeg_call_out.log" 1>&1 2>&2 
    log "FFmpeg call to macOS exited with $?"
    exit $?  
}



cmd="$@"

if [ "$CALL_ORIGINAL_ONLY" = true ] || [ "$ENABLE_CALL_RECORDING" = true ]; then
    # log "Will record call" 
    record_call "$cmd"
fi


if [ "$CALL_ORIGINAL_ONLY" = true ]; then
    log "Forwarding is diabled, calling original ffmpeg"
    execute_local_ffmpeg "$@"
    exit 0
fi

# Validate macOS environment variables
if ! is_forwarding_available; then
    log "Missing macOS side configs in ENV, fallback to local forwarding"
    execute_local_ffmpeg "$@"
    exit 0
fi


cmd_with_mapped_paths=$(replace_paths "$cmd")
execute_macos_ffmpeg "$cmd_with_mapped_paths"
