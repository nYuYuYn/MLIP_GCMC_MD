import os
import re
import numpy as np
import pandas as pd

def convert_dump_file(input_file, output_file, element_map):
    """
    Convert atom types to element names in a LAMMPS dump file.
    
    Parameters:
    input_file (str): Path to the original LAMMPS dump file
    output_file (str): Path to save the modified file
    element_map (dict): Dictionary mapping atom types to element names
    """
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        in_atoms_section = False
        
        for line in infile:
            line = line.strip()
            
            # Check if we're starting the atoms section
            if line.startswith("ITEM: ATOMS"):
                in_atoms_section = True
                outfile.write(line + '\n')
                continue
            
            # Process atom lines when we're in the atoms section
            if in_atoms_section and not line.startswith("ITEM:"):
                parts = line.split()
                
                if len(parts) >= 2:  # Ensure we have at least atom ID and type
                    # Get the atom type (2nd column in your file)
                    atom_type = int(parts[1])
                    
                    # Replace type number with element name if in our map
                    if atom_type in element_map:
                        parts[1] = element_map[atom_type]
                    
                    # Write the modified line
                    outfile.write(' '.join(parts) + '\n')
                else:
                    # Just write the line unchanged if it doesn't match expected format
                    outfile.write(line + '\n')
            else:
                # If we encounter a new "ITEM:" line, we're leaving the atoms section
                if line.startswith("ITEM:") and not line.startswith("ITEM: ATOMS"):
                    in_atoms_section = False
                
                # Write all non-atom lines unchanged
                outfile.write(line + '\n')

element_map = {
    1: "C",
    2: "Mn", 
    3: "Fe",
    4: "N",
    5: "Na",
    6: "O",
    7: "H"
}
for i in range(8):
    input_file = f'dump.gcmc_{i+1}.trj'
    output_file = f'dump.gcmc_{i+1}.trj'
# Convert the file
    convert_dump_file(input_file, output_file, element_map)
    print(f"Conversion complete. Modified file saved as {output_file}")