import numpy as np
import sys

def load_from_13th_line(filename):
    try:
        with open(filename, 'r') as file:
            lines = file.readlines()[12:]  # Read from the 13th line onwards (index 12)
        
        # Split each line into separate numbers
        numbers = []
        for line in lines:
            line_numbers = [float(num) for num in line.split()]  # Assuming numbers are floats
            numbers.append(line_numbers)
        
        # Convert the list of lists into a NumPy array
        return np.array(numbers)
    
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
    except IsADirectoryError:
        print(f"Error: '{filename}' is a directory, not a file.")
    except IOError:
        print(f"Error: Could not read file '{filename}'.")
    except Exception as e:
        print(f"Error: {e}")

def turn_into_cube(filename1, filename2, p):
    small_data = load_from_13th_line(filename1)
    big_data = load_from_13th_line(filename2)
    
    ### Cut into cube
    out_cube = []
    for i in range(big_data.shape[0]):
        if (abs(big_data[i, 2:]) > 7).any():
            out_cube.append(i)
    in_cube = [num for num in range(big_data.shape[0]) if num not in out_cube]
    big_data_cube = big_data[in_cube]
    
    ### Sort the atoms from small_data to the front
    same_line = []
    diff_line = []
    for i in range(big_data_cube.shape[0]):
        if big_data_cube[i, 2:].tolist() in small_data[:, 2:].tolist():
            same_line.append(i)
        if big_data_cube[i, 2:].tolist() not in small_data[:, 2:].tolist():
            diff_line.append(i)
    
    big_data_modify = np.ones(big_data_cube.shape)
    for i in range(len(same_line)):
        big_data_modify[i] = big_data_cube[same_line[i]]
    for i in range(len(same_line), big_data_cube.shape[0]):
        big_data_modify[i] = big_data_cube[diff_line[i - len(same_line)]]

    big_data_modify[:, 0] = range(big_data_cube.shape[0])
    
    ### Header information
    atom_data = big_data_modify
    xlo, xhi = -7.5, 7.5
    ylo, yhi = -7.5, 7.5
    zlo, zhi = -7.5, 7.5
    xy, xz, yz = 0, 0, 0
    num_atoms = len(atom_data)
    num_atom_types = len(np.unique(atom_data[:, 1]))
    
    # Writing to file
    filename = f'lammps.data{p}'
    with open(filename, 'w') as f:
        # Writing header lines
        f.write("\n")
        f.write(f"{xlo} {xhi} xlo xhi\n")
        f.write(f"{ylo} {yhi} ylo yhi\n")
        f.write(f"{zlo} {zhi} zlo zhi\n")
        f.write(f"{xy} {xz} {yz} xy xz yz\n\n")
        
        f.write(f"{num_atoms} atoms\n\n")
        f.write(f"{num_atom_types} atom types\n\n")
        
        f.write("Atoms\n\n")
        
        # Writing atom data
        for i in range(num_atoms):
            atom_id = int(atom_data[i, 0])+1
            atom_type = int(atom_data[i, 1])
            x = atom_data[i, 2]
            y = atom_data[i, 3]
            z = atom_data[i, 4]
            f.write(f"{atom_id} {atom_type} {x} {y} {z}\n")
            
    # Record how many atoms should be fixed
    filename = f'fix_atom_num.txt{p}'
    with open(filename, 'w') as f:       
        f.write(f"{len(same_line)}")

if __name__ == "__main__":
    import sys
    p = int(sys.argv[1])
    filename1 = f"relax_PBC.data{p}"
    filename2 = f"relax_PBC_2.data{p}"
    print(f"turn into cube {filename1} {filename2} is starting!")
    turn_into_cube(filename1, filename2, p)

