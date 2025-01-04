#!/bin/bash

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------
progress_file="progress.log"
summary_file="detailed-summary.txt"
main_dir="$(pwd)"

# -----------------------------------------------------------------------------
# Helper: Check if file path is already in progress.log
# -----------------------------------------------------------------------------
is_processed() {
    local path="$1"
    grep -Fxq "$path" "$main_dir/$progress_file"
}

# -----------------------------------------------------------------------------
# Initialize log files if they don't exist
# -----------------------------------------------------------------------------
touch "$main_dir/$progress_file"
touch "$main_dir/$summary_file"

echo "Script started at $(date)" >> "$main_dir/$progress_file"
echo "Summaries will be saved to $summary_file" >> "$main_dir/$progress_file"

# -----------------------------------------------------------------------------
# process_files: Splits each .vtt file into chunks and summarizes them
# -----------------------------------------------------------------------------
process_files() {
    local dir="$1"
    echo "Processing directory: $dir"

    # Iterate over each .vtt file in this directory
    for file in "$dir"/*.vtt; do
        # Skip if no .vtt file exists (glob didn’t match)
        [ -e "$file" ] || continue

        # Double-check it's a regular file
        if [ -f "$file" ]; then
            # Example of skipping overview.vtt if needed
            local file_name
            file_name="$(basename "$file")"
            if [ "$file_name" = "overview.vtt" ]; then
                echo "Skipping $file_name"
                continue
            fi

            # Get absolute path (so we log exactly this in progress_file)
            local file_path
            file_path="$(realpath "$file")"

            # Process only if not processed before
            if ! is_processed "$file_path"; then
                echo "Processing $file_path"
                echo "Processing $file_path" >> "$main_dir/$progress_file"

                # -----------------------------------------------------------------------------
                # 1. Create a temporary directory for splitting into chunks
                # -----------------------------------------------------------------------------
                local sanitized_name
                sanitized_name="$(basename "$file" | tr -d '[:space:]')"
                local temp_dir
                temp_dir="$(mktemp -d "$dir/tmp_${sanitized_name}_XXXXXX")"

                echo "Temporary directory created: $temp_dir" >> "$main_dir/$progress_file"

                # -----------------------------------------------------------------------------
                # 2. Split the file into 200-line chunks
                # -----------------------------------------------------------------------------
                split -l 100 "$file" "$temp_dir/chunk_"

                # -----------------------------------------------------------------------------
                # 3. Summarize each chunk and append to the summary file
                # -----------------------------------------------------------------------------
                for chunk_file in "$temp_dir"/chunk_*; do
                    [ -f "$chunk_file" ] || continue
                    echo "Summarizing chunk: $(basename "$chunk_file")"

                    # Use a more detailed prompt to get more comprehensive results
                    ollama run vanilj/phi-4 "Provide a detailed summary of the following text:" \
                        < "$chunk_file" | tee -a "$main_dir/$summary_file"
                    echo "" >> "$main_dir/$summary_file"
                done

                # -----------------------------------------------------------------------------
                # 4. Remove temp directory and mark as processed
                # -----------------------------------------------------------------------------
                rm -rf "$temp_dir"
                echo "Temporary directory $temp_dir removed" >> "$main_dir/$progress_file"

                # Log the file path to avoid re-processing next time
                echo "$file_path" >> "$main_dir/$progress_file"
            fi
        fi
    done
}

# -----------------------------------------------------------------------------
# process_subdirectories: Recursively handle subdirectories in version-sorted order
# -----------------------------------------------------------------------------
process_subdirectories() {
    local parent_dir="$1"

    # Gather immediate subdirectories and sort them with -V (natural sort)
    mapfile -t dirs < <(find "$parent_dir" -mindepth 1 -maxdepth 1 -type d | sort -V)

    for dir_path in "${dirs[@]}"; do
        # Process files in this subdirectory
        process_files "$dir_path"
        # Recurse deeper
        process_subdirectories "$dir_path"
    done
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
process_files "$main_dir"            # Process .vtt files in the main directory
process_subdirectories "$main_dir"   # Then handle subdirectories

echo "Script completed at $(date)" >> "$main_dir/$progress_file"
