#!/bin/bash

# Step 1: Separate every configuration into temporary files
temp_dir="temp_configs"
mkdir -p "$temp_dir"

config_count=0
while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line == "BEGIN_CFG" ]]; then
        ((config_count++))
        current_file="${temp_dir}/config_${config_count}.tmp"
        echo "$line" > "$current_file"
    elif [[ $line == "END_CFG" ]]; then
        echo "$line" >> "$current_file"
    else
        echo "$line" >> "$current_file"
    fi
done < train.cfg

echo "Step 1: Configurations separated into temporary files."

# Step 2: Merge configurations with the same number of atoms
for tmp_file in "${temp_dir}"/*.tmp; do
    atom_count=$(awk '/^ Size/{getline; print $1; exit}' "$tmp_file")
    cat "$tmp_file" >> "Na_${atom_count}.cfg"
done

echo "Step 2: Configurations merged based on atom count."

# Step 3: Remove temporary files
rm -r "$temp_dir"

echo "Step 3: Temporary files removed."

echo "Process completed. Merged files are named as Na_[number_of_atoms].cfg"