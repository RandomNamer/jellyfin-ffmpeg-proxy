#bash
FORCE_INSERT_TRANSCODE="-init_hw_device videotoolbox=vt -hwaccel videotoolbox -hwaccel_output_format videotoolbox_vld -noautorotate"

log() {
    local message="${1}"
    local level="${2:-DBG}"  

    # Write the log message with a timestamp and level
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
}

format_arguments() {
    local raw_args="$1"
    local formatted_args=""
    local flag_regex='\ -[^ |0-9][^ ]*'  
    local flag_regex_first='^-[^ |0-9][^ ]*'
    local insert_position=0

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
            echo "Next flag: $next_flag"
            local params="${raw_args%%$next_flag*}"  # Everything before the next flag
            params="${params#"${params%%[! ]*}"}"

            if [[ "$next_flag" == *"-b:v"* ]]; then 
                streaming=true
            fi
            

            # Quote the parameters if necessary
            if [[ -n "$params" ]]; then
                # if [[ "$params" == *" "* ]]; then
                #     formatted_args+="\"$params\" "
                # else
                #     formatted_args+="$params "
                # fi
                formatted_args+="\"$params\" "
                if [[ "$params" == "copy" ]]; then
                    remuxing=true
                    log "detected copy before $next_flag"
                fi
            fi

            if [[ "$next_flag" == *"-canvas_size"* ]]; then
                insert_position=${#formatted_args}
                echo "insert_position: $insert_position"
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
            # formatted_args+="\"$raw_args\" "
            if [[ "$raw_args" == "copy" ]]; then
                remuxing=true
            fi
            break
        fi
    done

    # log "streaming: $streaming, remuxing: $remuxing"
    if [[ "$streaming" == true ]]; then
        if [[ "$remuxing" == true ]]; then
            :
        else
            log "This is transcoding, inserting flags to force enable apple hardware acceleration"
            formatted_args="${formatted_args:0:$insert_position}$FORCE_INSERT_TRANSCODE ${formatted_args:$insert_position}"
        fi
    fi

    echo "$formatted_args"
}

cmd_text="$@"
formatted_args=$(format_arguments "$cmd_text")
echo "$formatted_args"