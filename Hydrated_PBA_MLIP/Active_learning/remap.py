import numpy as np
import sys

def load_multi_section_cfg_no_grade(filename):
    energies = []
    supercell_list = []
    atom_data_list = []
    stress_data_list = []
    grade_data_list = []
    
    try:
        with open(filename, 'r') as file:
            content = file.read()
            
            # Split the content into sections
            cfg_sections = content.split('BEGIN_CFG')[1:]  # Skip the first empty split
            
            for section in cfg_sections:
                lines = section.strip().split('\n')
                
                # Extract Size
                size = int(next(line.strip() for line in lines if line.strip().isdigit()))

                # Extract Supercell
                supercell_start = next(i for i, line in enumerate(lines) if line.strip().startswith('Supercell'))
                supercell = np.array([list(map(float, line.split()[:])) for line in lines[supercell_start+1:supercell_start+3+1]])
                supercell_list.append(supercell)
                
                # Extract AtomData
                atom_data_start = next(i for i, line in enumerate(lines) if line.strip().startswith('AtomData:'))
                atom_data = np.array([list(map(float, line.split())) for line in lines[atom_data_start+1:atom_data_start+size+1]])
                atom_data_list.append(atom_data)
                
                # Extract Energy
                energy_line_index = next(i for i, line in enumerate(lines) if line.strip().startswith('Energy'))
                energy = float(lines[energy_line_index+1].split()[0])
                energies.append(energy)
                
                # Extract PlusStress
                stress_line = next(line for line in lines if line.strip().startswith('PlusStress:'))
                stress = np.array(list(map(float, lines[lines.index(stress_line) + 1].split())))
                stress_data_list.append(stress)
        
        return np.array(energies), np.array(supercell_list), atom_data_list, np.array(stress_data_list)
    
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
    except IsADirectoryError:
        print(f"Error: '{filename}' is a directory, not a file.")
    except IOError:
        print(f"Error: Could not read file '{filename}'.")
    except Exception as e:
        print(f"Error: {e}")
        return None, None, None, None

def write_cfg(E, supercell, F, S, output_file, remap_types=False):
    type_map = {0: 0, 1: 1, 2: 2, 3: 3, 4: 5, 5: 6}  # skips 4 → maps to 5,6

    with open(output_file, 'w') as file:
        for cfg_num in range(E.shape[0]):
            file.write("BEGIN_CFG\n")
            file.write(" Size\n")
            file.write(f"    {F[cfg_num].shape[0]}\n")
            file.write(" Supercell\n") 
            for row in supercell[cfg_num]:
                formatted_row = " ".join([f"{elem}" for elem in row])
                file.write(formatted_row + "\n")
            file.write(" AtomData:  id type       cartes_x      cartes_y      cartes_z           fx          fy          fz\n")
    
            for atom in F[cfg_num]:
                atom_id = int(atom[0])
                atom_type = int(atom[1])
                if remap_types:
                    atom_type = type_map[atom_type]
                x, y, z = map(float, atom[2:5])
                fx, fy, fz = map(float, atom[5:])
                file.write(f"    {atom_id}    {atom_type}    {x:.6f}    {y:.6f}    {z:.6f}    {fx:.6f}    {fy:.6f}    {fz:.6f}\n")
            file.write(" Energy\n")
            file.write(f"    {E[cfg_num]}\n")
            file.write(" PlusStress:  xx          yy          zz          yz          xz          xy\n")
            stress = " ".join([f"{elem}" for elem in S[cfg_num]])
            file.write(f"    {stress}\n")
            file.write("END_CFG\n")
            file.write("\n")

if len(sys.argv) < 2:
    print("Usage: python remap.py <cfg_file>")
    sys.exit(1)

cfg_file = sys.argv[1]
E, supercell, F, S = load_multi_section_cfg_no_grade(cfg_file)
write_cfg(E, supercell, F, S, cfg_file, True)