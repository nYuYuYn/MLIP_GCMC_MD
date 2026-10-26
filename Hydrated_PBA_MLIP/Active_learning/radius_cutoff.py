import numpy as np

def load_selected_cfg(filename):
    supercell_list = []
    atom_data_list = []
    
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
        
        return np.array(supercell_list), atom_data_list
    
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
    except IsADirectoryError:
        print(f"Error: '{filename}' is a directory, not a file.")
    except IOError:
        print(f"Error: Could not read file '{filename}'.")
    except Exception as e:
        print(f"Error: {e}")
        return None, None

def calculate_min_distances(supercell_list, atom_data_list):
    """
    Calculates the minimum interatomic distance for a list of structures
    accounting for Periodic Boundary Conditions (PBC).
    """
    min_distances = []
    
    for idx, (supercell, atom_data) in enumerate(zip(supercell_list, atom_data_list)):
        # 1. Extract Cartesian Coordinates
        # IMPORTANT: In standard MLIP .cfg files, AtomData is usually formatted as:
        # [id, type, cartes_x, cartes_y, cartes_z, fx, fy, fz]
        # So Cartesian coordinates are at indices 2, 3, and 4. 
        # Adjust the slice `[:, 2:5]` if your .cfg format differs.
        coords = atom_data[:, 2:5]
        
        # If there's only 1 atom in the cell, min distance isn't well-defined in the same way
        if len(coords) <= 1:
            min_distances.append(np.inf)
            continue
            
        # 2. Calculate pairwise differences: r_ij = r_i - r_j
        # Shape becomes (N, N, 3)
        diffs = coords[:, np.newaxis, :] - coords[np.newaxis, :, :]
        
        # 3. Apply Minimum Image Convention for PBC
        # Convert to fractional coordinates using the inverse of the supercell matrix
        inv_supercell = np.linalg.inv(supercell)
        diffs_frac = diffs @ inv_supercell
        
        # Wrap fractional coordinates to [-0.5, 0.5] to find the shortest periodic path
        diffs_frac = diffs_frac - np.round(diffs_frac)
        
        # Convert back to Cartesian coordinates
        diffs_cart = diffs_frac @ supercell
        
        # 4. Calculate Euclidean distances
        distances = np.linalg.norm(diffs_cart, axis=-1)
        
        # 5. Mask the diagonal (self-distances are always 0)
        np.fill_diagonal(distances, np.inf)
        
        # Find the absolute minimum distance in this structure
        min_dist = np.min(distances)
        min_distances.append(min_dist)
        
    return np.array(min_distances)
    
def write_cfg(supercell, F, output_file):
    with open(output_file, 'w') as file:
        for cfg_num in range(supercell.shape[0]):
            file.write("BEGIN_CFG\n")
            file.write(" Size\n")
            file.write(f"    {F[cfg_num].shape[0]}\n")
            file.write(" Supercell\n") 
            for row in supercell[cfg_num]:
                # Format each element in the row to scientific notation with 17 decimals
                formatted_row = " ".join([f"{elem}" for elem in row])
                file.write(formatted_row + "\n")
            file.write(" AtomData:  id type       cartes_x      cartes_y      cartes_z\n")
    
            for atom in F[cfg_num]:
                atom_id = int(atom[0])
                atom_type = int(atom[1])
                x, y, z = map(float, atom[2:5])
                file.write(f"    {atom_id}    {atom_type}    {x:.6f}    {y:.6f}    {z:.6f}\n")      
            file.write("END_CFG\n")
            file.write("\n")
            
# --- Execution ---
if __name__ == "__main__":
    filename = "selected.cfg"
    supercell, F_DFT = load_selected_cfg(filename)
    
    if supercell is not None:
        min_distances = calculate_min_distances(supercell, F_DFT)  # fix #1
        print(f'There are {min_distances.shape[0]} structures in the selected.cfg')
        
        good_apple_ls = np.where(min_distances >= 0.2)  # fix #2
        print(f'There are {len(good_apple_ls[0])} structures with min_distance >= 0.2 A')
        
        F_DFT = np.array(F_DFT, dtype=object)
        F = F_DFT[good_apple_ls[0]]
        supercell = supercell[good_apple_ls[0]]

        write_cfg(supercell, F, './filtered_selected.cfg')  # optional: avoid overwriting input