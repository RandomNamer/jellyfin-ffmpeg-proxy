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
LINUX_FFMPEG="$SCRIPT_DIR/ffprobe_original"

LOG_FILE="$SCRIPT_DIR/ffprobe_calls.log"

MACOS_LOG_FILE="/Users/zzy/Desktop/ffprobe_call_out.log"

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
    return 0
    if [ -z "$MACOS_USER" ] || [ -z "$MACOS_PASSWORD" ] || [ -z "$MACOS_PATH_MAP" ]; then
        return 1  
    fi
    return 0 
}

execute_macos_ffmpeg() {
    local raw_args="$1"

    log "Transformed ffmpeg args: $raw_args"

    # Format the arguments based on flags
    local formatted_args
    formatted_args=$(format_arguments "$raw_args")

    local macos_cmd_final="$MACOS_FFMPEG $formatted_args"

    log "Forwarding FFmpeg Command to macOS: $formatted_args"

    sshpass -p "$MACOS_PASSWORD" ssh -o StrictHostKeyChecking=no "$MACOS_USER@$MACOS_HOST" \
        "$MACOS_FFMPEG $formatted_args | tee -a $MACOS_LOG_FILE" \
        1>&1 2>&2

    local exit_code=$?
    log "FFmpeg call to macOS exited with $exit_code"
    exit $exit_code
}


format_arguments() {
    local raw_args="$1"
    local formatted_args=""
    local flag_regex='\ -[^ |0-9][^ ]*'  
    local flag_regex_first='^-[^ |0-9][^ ]*'

    # Handle the first flag (if any)
    if [[ "$raw_args" =~ $flag_regex_first ]]; then
        local first_flag="${BASH_REMATCH[0]}"
        formatted_args+="$first_flag "
        raw_args="${raw_args#*$first_flag}"  # Remove the matched first flag
    fi

    while [[ -n "$raw_args" ]]; do
        # Match the next flag
        if [[ "$raw_args" =~ $flag_regex ]]; then
            local next_flag="${BASH_REMATCH[0]}"
            # echo "Next flag: $next_flag"
            local params="${raw_args%%$next_flag*}"  # Everything before the next flag
            params="${params#"${params%%[! ]*}"}"
            

            # Quote the parameters if necessary
            if [[ -n "$params" ]]; then
                # if [[ "$params" == *" "* ]]; then
                #     formatted_args+="\"$params\" "
                # else
                #     formatted_args+="$params "
                # fi
                formatted_args+="\"$params\" "
            fi

            # Add the next flag to the formatted output
            formatted_args+="$next_flag "
            raw_args="${raw_args#*$next_flag}"  # Remove the processed segment
        else
            # No more flags; treat the remaining raw_args as parameters
            raw_args="${raw_args#"${raw_args%%[! ]*}"}"  # Trim leading spaces
            if [[ "$raw_args" == *" "* ]]; then
                formatted_args+="\"$raw_args\" "
            else
                formatted_args+="$raw_args "
            fi
            break
        fi
    done

    echo "$formatted_args"
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
