# Input file containing multiple sections:
input_file="nbh.cfg"

# Initialize variables
section_num=0
output_file=""

# Read through the input file line by line
while IFS= read -r line; do
	# Check if the line marks the beginning of a section
	if [[ "$line" == "BEGIN_CFG" ]]; then
		# Increment the section number and set the output file name
		section_num=$((section_num + 1))
		output_file="section_${section_num}.cfg"
		echo "Processing section $section_num into file $output_file"
	fi
	
	# If we are inside a section, write the line to the output file
	if [[ -n "$output_file" ]]; then
		echo "$line" >> "$output_file"
	fi

	# Check if the line marks the end of a section
	if [[ "$line" == "END_CFG" ]]; then
		# Close the current section by resetting the output file name
		output_file=""
	fi
done < "$input_file"

echo "Done processing all sections."
