#!/bin/bash
temps=(300 400 500 600 700 800 900 1000 1100)

for temp in "${temps[@]}"; do
    dir="Nt_$temp"
    if [ -d "$dir" ]; then
        echo "$dir:"
        # Loop through subdirectories 1, 2, 3
        for subdir in 1 2 3 4; do
            if [ -d "$dir/$subdir" ]; then
                # Find the highest indexed file in this subdirectory
                highest_file=$(find "$dir/$subdir" -type f -name "${temp}loop_bias_*.data" ! -name "*-checkpoint.data" | sort -V | tail -n 1)
                if [ -n "$highest_file" ]; then
                    echo "  $subdir: $highest_file"
                fi
            fi
            
            if [ -d "$dir/$subdir" ]; then
                # Find all log files in this subdirectory and extract the highest number
                highest_num=$(find "$dir/$subdir" -type f -name "loop_bias_${subdir}.log_*" ! -name "*jpg" -printf '%f\n' 2>/dev/null | \
                             sed 's/.*\.log_//' | \
                             sort -n | \
                             tail -n 1)
                
                if [ -n "$highest_num" ]; then
                    echo "  $subdir: highest log number is $highest_num"
                fi
            fi
            
        done
        echo  # Empty line for readability between temperature directories
    fi
done

