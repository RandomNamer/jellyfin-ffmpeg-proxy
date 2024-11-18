#bash
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
            echo "Next flag: $next_flag"
            local params="${raw_args%%$next_flag*}"  # Everything before the next flag
            params="${params#"${params%%[! ]*}"}"
            

            # Quote the parameters if necessary
            if [[ -n "$params" ]]; then
                if [[ "$params" == *" "* ]]; then
                    formatted_args+="\"$params\" "
                else
                    formatted_args+="$params "
                fi
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

cmd_text="$@"
formatted_args=$(format_arguments "$cmd_text")
echo "$formatted_args"