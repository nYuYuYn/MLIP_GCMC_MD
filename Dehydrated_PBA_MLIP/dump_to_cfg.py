import sys
import os

def read_lammps_data_file(data_file):
    """Read LAMMPS data file and extract atom information and box dimensions"""
    with open(data_file, 'r') as f:
        lines = f.readlines()
    
    # Initialize variables
    num_atoms = 0
    box_bounds = {}
    atoms = []
    reading_atoms = False
    atoms_section_found = False
    
    # Debug: print first few lines to understand format
    print("First 10 lines of data file:")
    for i, line in enumerate(lines[:10]):
        print(f"{i+1}: {line.rstrip()}")
    
    for i, line in enumerate(lines):
        line_stripped = line.strip()
        
        # Get number of atoms
        if 'atoms' in line_stripped and not line_stripped.startswith('#'):
            try:
                num_atoms = int(line_stripped.split()[0])
                print(f"Found {num_atoms} atoms")
            except:
                pass
            
        # Get box bounds - handle both formats
        if 'xlo xhi' in line_stripped or (len(line_stripped.split()) >= 4 and 'xlo' in line_stripped):
            try:
                parts = line_stripped.split()
                xlo, xhi = float(parts[0]), float(parts[1])
                box_bounds['x'] = [xlo, xhi]
                print(f"X bounds: {xlo} to {xhi}")
            except:
                pass
        elif 'ylo yhi' in line_stripped or (len(line_stripped.split()) >= 4 and 'ylo' in line_stripped):
            try:
                parts = line_stripped.split()
                ylo, yhi = float(parts[0]), float(parts[1])
                box_bounds['y'] = [ylo, yhi]
                print(f"Y bounds: {ylo} to {yhi}")
            except:
                pass
        elif 'zlo zhi' in line_stripped or (len(line_stripped.split()) >= 4 and 'zlo' in line_stripped):
            try:
                parts = line_stripped.split()
                zlo, zhi = float(parts[0]), float(parts[1])
                box_bounds['z'] = [zlo, zhi]
                print(f"Z bounds: {zlo} to {zhi}")
            except:
                pass
            
        # Look for Atoms section
        if line_stripped == 'Atoms' or line_stripped.startswith('Atoms #'):
            reading_atoms = True
            atoms_section_found = True
            print(f"Found Atoms section at line {i+1}")
            continue
            
        # Skip empty lines and comments after Atoms header
        if reading_atoms and (not line_stripped or line_stripped.startswith('#')):
            continue
            
        # Stop reading atoms if we hit another section
        if reading_atoms and line_stripped and (
            line_stripped.startswith('Velocities') or 
            line_stripped.startswith('Bonds') or
            line_stripped.startswith('Angles') or
            line_stripped.startswith('Dihedrals') or
            line_stripped.startswith('Impropers')
        ):
            print(f"Stopped reading atoms at section: {line_stripped}")
            break
            
        # Read atom data
        if reading_atoms and line_stripped:
            try:
                parts = line_stripped.split()
                if len(parts) >= 5:  # Minimum: id type x y z
                    atom_id = int(parts[0])
                    atom_type = int(parts[1]) - 1  # Convert to 0-based
                    x, y, z = map(float, parts[2:5])
                    
                    # Check if forces are available
                    if len(parts) >= 8:
                        fx, fy, fz = map(float, parts[5:8])
                    else:
                        fx = fy = fz = 0.0
                        
                    atoms.append([atom_id, atom_type, x, y, z, fx, fy, fz])
                    
                    if len(atoms) <= 5:  # Debug: show first few atoms
                        print(f"Atom {len(atoms)}: ID={atom_id}, type={atom_type+1}, pos=({x:.3f},{y:.3f},{z:.3f})")
                        
            except (ValueError, IndexError) as e:
                if len(atoms) <= 5:  # Only show errors for first few lines
                    print(f"Error parsing line {i+1}: {line_stripped[:50]}... Error: {e}")
                continue
    
    print(f"Successfully read {len(atoms)} atoms")
    if not atoms_section_found:
        print("WARNING: No 'Atoms' section found in data file")
    
    return num_atoms, box_bounds, atoms

def read_lammps_dump_file(dump_file):
    """Read LAMMPS dump file and extract atom information and box dimensions"""
    with open(dump_file, 'r') as f:
        lines = f.readlines()
    
    # Find the number of atoms
    num_atoms = 0
    box_bounds = {}
    atoms = []
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        if line == "ITEM: NUMBER OF ATOMS":
            num_atoms = int(lines[i+1].strip())
            i += 2
        elif line.startswith("ITEM: BOX BOUNDS"):
            # Read box bounds
            for j, dim in enumerate(['x', 'y', 'z']):
                bounds = lines[i+1+j].split()
                box_bounds[dim] = [float(bounds[0]), float(bounds[1])]
            i += 4
        elif line.startswith("ITEM: ATOMS"):
            # Parse column headers
            headers = line.split()[2:]  # Skip "ITEM:" and "ATOMS"
            
            # Read atom data
            i += 1
            while i < len(lines) and not lines[i].startswith("ITEM:"):
                parts = lines[i].split()
                if len(parts) >= len(headers):
                    atom_data = {}
                    for k, header in enumerate(headers):
                        atom_data[header] = parts[k]
                    
                    # Extract required data
                    atom_id = int(atom_data.get('id', 0))
                    atom_type = int(atom_data.get('type', 1)) - 1  # Convert to 0-based
                    x = float(atom_data.get('x', 0.0))
                    y = float(atom_data.get('y', 0.0))
                    z = float(atom_data.get('z', 0.0))
                    
                    # Try to get forces if available
                    fx = float(atom_data.get('fx', 0.0))
                    fy = float(atom_data.get('fy', 0.0))
                    fz = float(atom_data.get('fz', 0.0))
                    
                    atoms.append([atom_id, atom_type, x, y, z, fx, fy, fz])
                i += 1
        else:
            i += 1
    
    return num_atoms, box_bounds, atoms

def convert_to_cfg(input_file, cfg_file):
    """Convert LAMMPS file to CFG format"""
    
    print(f"Reading from {input_file}")
    
    # Determine file type and read accordingly
    if input_file.endswith('.data'):
        num_atoms, box_bounds, atoms = read_lammps_data_file(input_file)
    else:  # Assume dump file
        num_atoms, box_bounds, atoms = read_lammps_dump_file(input_file)
    
    if not atoms:
        print("Error: No atoms found in the file")
        return
    
    print(f"Number of atoms: {num_atoms}")
    print(f"Box bounds: {box_bounds}")
    
    # Calculate supercell vectors
    if box_bounds:
        lx = box_bounds['x'][1] - box_bounds['x'][0]
        ly = box_bounds['y'][1] - box_bounds['y'][0]
        lz = box_bounds['z'][1] - box_bounds['z'][0]
    else:
        print("Warning: No box bounds found, using default values")
        lx = ly = lz = 10.0
    
    # Write CFG file
    with open(cfg_file, 'w') as f:
        f.write("BEGIN_CFG\n")
        f.write(" Size\n")
        f.write(f"    {len(atoms)}\n")
        f.write(" Supercell\n")
        f.write(f"    {lx:12.6f}      0.000000      0.000000\n")
        f.write(f"     0.000000     {ly:12.6f}      0.000000\n")
        f.write(f"     0.000000      0.000000     {lz:12.6f}\n")
        
        # Check if forces are non-zero for any atom
        has_forces = any(abs(atom[5]) > 1e-10 or abs(atom[6]) > 1e-10 or abs(atom[7]) > 1e-10 for atom in atoms)
        
        # Sort atoms by original ID to maintain consistency
        atoms_sorted = sorted(atoms, key=lambda x: x[0])
        
        if has_forces:
            f.write(" AtomData:  id type       cartes_x      cartes_y      cartes_z           fx          fy          fz\n")
            for i, (atom_id, atom_type, x, y, z, fx, fy, fz) in enumerate(atoms_sorted, 1):
                f.write(f"{i:>7}{atom_type:>5}{x:>14.6f}{y:>14.6f}{z:>14.6f}{fx:>12.6f}{fy:>12.6f}{fz:>12.6f}\n")
        else:
            f.write(" AtomData:  id type       cartes_x      cartes_y      cartes_z\n")
            for i, (atom_id, atom_type, x, y, z, fx, fy, fz) in enumerate(atoms_sorted, 1):
                f.write(f"{i:>7}{atom_type:>5}{x:>14.6f}{y:>14.6f}{z:>14.6f}\n")
        
        f.write("END_CFG\n")
    
    print(f"Conversion complete: {cfg_file}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <input_file> [output_file]")
        print("       python script.py <file_index>  (for batch processing)")
        sys.exit(1)
    
    if len(sys.argv) == 2:
        # Check if argument is a file or an index
        arg = sys.argv[1]
        if arg.isdigit():
            # Batch processing mode
            p = int(arg)
            # Try different possible input files
            possible_files = [
                f"relaxed_700loop_bias_{p}.data",
                f"relax_{p}.dump",
                f"relax_{p}.trj"
            ]
            
            input_file = None
            for pf in possible_files:
                if os.path.exists(pf):
                    input_file = pf
                    break
            
            if input_file is None:
                print(f"Error: No input file found for index {p}")
                print(f"Tried: {', '.join(possible_files)}")
                sys.exit(1)
                
            output_file = f"relax_{p}.cfg"
        else:
            # Direct file mode
            input_file = arg
            output_file = arg.rsplit('.', 1)[0] + '.cfg'
    else:
        input_file = sys.argv[1]
        output_file = sys.argv[2]
    
    convert_to_cfg(input_file, output_file)
    print(f'{input_file} has been converted to {output_file}')