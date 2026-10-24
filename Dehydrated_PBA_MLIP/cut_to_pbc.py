# Separate the cfg file into section
# Load Each section one by one
import numpy as np
import pandas as pd
import math
import os
import sys

# Check if the required argument is provided
if len(sys.argv) < 2:
    print("Usage: python script.py <p>")
    sys.exit(1)

p = int(sys.argv[1])
input_file = f"./section_{p}.cfg"
output_file1 = f"./PBC_{p}.data"
output_file2 = f"./center_{p}.txt"

def load_cfg(filename):
    try:
        with open(filename, 'r') as file:
            lines = file.readlines()[4:-5]  # Read from the 5th line onwards 
        
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
        
def distance_3d(point1, point2):
    return np.linalg.norm(point1 - point2)

def find_nearest_atom(data, origin, target_types):
    target_atoms = data[np.isin(data[:, 1], target_types)]
    if len(target_atoms) > 0:
        distances = np.linalg.norm(target_atoms[:, 2:5] - origin, axis=1)
        nearest_index = np.argmin(distances)
        nearest_atom = target_atoms[nearest_index]
        distance = distances[nearest_index]
        return nearest_atom, distance
    return None, None

data = load_cfg(input_file)
if data is not None:
    print(f"Loaded data from {input_file}, cut into PBC is starting!")
else:
    print(f"Failed to load data from {input_file}")

# Assuming 'data' is your numpy array with structure [id, type, x, y, z] for each row
origin = np.array([0, 0, 0])
first_atom_type = data[0, 1]

if first_atom_type == 0:
    target_types = [2]
elif first_atom_type == 3:
    target_types = [1]
elif first_atom_type == 4:
    target_types = [1]
elif first_atom_type == 1:
    target_types = [2]
elif first_atom_type == 2:
    target_types = [1]
else:
    print(f"First atom type {first_atom_type} does not match any specified conditions.")
    exit()

nearest_atom, distance = find_nearest_atom(data, origin, target_types)

if nearest_atom is not None:
    print(f"The first atom is of type {first_atom_type}")
    print(f"The nearest atom of type {' or '.join(map(str, target_types))} to (0,0,0) is:")
    print(f"ID: {nearest_atom[0]}")
    print(f"Type: {nearest_atom[1]}")
    print(f"Coordinates: {nearest_atom[2:5]}")
    print(f"Distance from origin: {distance:.6f}")
else:
    print(f"No atoms of type {' or '.join(map(str, target_types))} found in the data.")
    
origin = nearest_atom[2:5] #Coordinates: [-0.970938 -2.191026  0.979268]
if target_types[0] == 2:
    type_atoms = data[data[:, 1] == 1]
if target_types[0] == 1:
    type_atoms = data[data[:, 1] == 2]
    
    
distances = np.linalg.norm(type_atoms[:, 2:5] - origin, axis=1)
type_indices = np.where(data[:, 1] == 2)[0]
selected = distances[(distances > 6) & (distances < 10)]
corner_indices = [np.where(distances == element)[0][0] for element in selected]
vertices = type_atoms[corner_indices][:,2:]

# Step 1: Sort by z-coordinate
sorted_by_z = vertices[vertices[:, 2].argsort()]

# Step 2: Sort the first 4 (smallest z-values) by y-coordinate
first_half_sorted_by_y = sorted_by_z[:4][sorted_by_z[:4][:, 0].argsort()]

# Step 3: Sort the last 4 (largest z-values) by y-coordinate
second_half_sorted_by_y = sorted_by_z[4:][sorted_by_z[4:][:, 0].argsort()]

# Combine the two sorted halves
reordered_coords = np.vstack((first_half_sorted_by_y, second_half_sorted_by_y))
reordered_coords[[1, 2]] = reordered_coords[[2, 1]]
reordered_coords[[5, 6]] = reordered_coords[[6, 5]]

vertices = reordered_coords
faces = [
    [vertices[0], vertices[1], vertices[5], vertices[4]],  # Front face
    [vertices[0], vertices[1], vertices[3], vertices[2]],  # Bottom face
    [vertices[0], vertices[2], vertices[6], vertices[4]],  # Top face
    [vertices[1], vertices[3], vertices[7], vertices[5]],  # Back face
    [vertices[2], vertices[3], vertices[7], vertices[6]],  # Left face
    [vertices[4], vertices[5], vertices[7], vertices[6]]   # Right face
]

def plane_equation(p1, p2, p3):
    """Calculate the plane equation Ax + By + Cz + D = 0"""
    v1 = p2 - p1
    v2 = p3 - p1
    normal = np.cross(v1, v2)
    A, B, C = normal
    D = -np.dot(normal, p1)
    return A, B, C, D
def is_inside_or_on_rhombohedron(point, corners, tolerance=120):
    """Check if a point is inside or on the planes of the rhombohedron"""
    planes = [
        plane_equation(corners[0], corners[2], corners[1]),
        plane_equation(corners[0], corners[4], corners[2]),
        plane_equation(corners[0], corners[1], corners[4]),
        plane_equation(corners[7], corners[6], corners[5]),
        plane_equation(corners[7], corners[5], corners[3]),
        plane_equation(corners[7], corners[3], corners[6])
    ]

    for A, B, C, D in planes:
        if A*point[0] + B*point[1] + C*point[2] + D > tolerance:
            return False
    return True
# Rhombohedron corners
corners = vertices
# Function to filter atoms
def filter_atoms_in_or_on_rhombohedron(atoms, corners):
    return [atom for atom in atoms if is_inside_or_on_rhombohedron(atom, corners)]
atoms_inside_or_on = filter_atoms_in_or_on_rhombohedron(data[:,2:], corners)

def find_atom_indices(atoms_inside_or_on, data_array):
    # Convert the list of numpy arrays to a 2D numpy array
    atoms_inside_or_on = np.array([atom for atom in atoms_inside_or_on])
    
    # Extract just the coordinate columns from the data array
    data_coordinates = data[:, 2:5].astype(float)
    
    # Find matching indices
    indices = []
    for atom in atoms_inside_or_on:
        # Find rows where all coordinates match (within a small tolerance)
        matches = np.all(np.isclose(data_coordinates, atom, atol=1e-6), axis=1)
        if np.any(matches):
            # Get the index of the first match
            index = np.where(matches)[0][0]
            indices.append(index)
    
    return indices
    
matching_indices = find_atom_indices(atoms_inside_or_on, data)

print(f'{len(atoms_inside_or_on)} atoms are cut into PBC')

slected_data = data[matching_indices]
slected_data[:,0] = range(len(slected_data[:,0]))
slected_data[:,0] = slected_data[:,0].astype(int)
slected_data[:,1] = slected_data[:,1].astype(int)

origin = nearest_atom[2:5] 
distance_R = np.linalg.norm(slected_data[:, 2:5] - origin, axis=1)
to_fix = distance_R[distance_R <= 4.5]
to_relax = distance_R[distance_R > 4.5]
fix_indices = [np.where(distance_R == element)[0][0] for element in to_fix]

print(f'{len(fix_indices)} atoms will be fixed')

# Calculate the lattice vectors
a = vertices[1] - vertices[0]
b = vertices[2] - vertices[0]
c = vertices[4] - vertices[0]

# Calculate the tilt factors
xy = abs(b[0])
xz = abs(c[0])
yz = abs(c[1])

lx = abs(vertices[:,0].min()-vertices[:,0].max())
ly = abs(vertices[:,1].min()-vertices[:,1].max())
lz = abs(vertices[:,2].min()-vertices[:,2].max())

# Extract information
num_atoms = len(slected_data)
num_atom_types = len(np.unique(slected_data[:, 1]))

x_min, x_max = vertices[:,0].min(), vertices[:,0].max()-(lx-lz)
y_min, y_max = vertices[:,1].min(), vertices[:,1].max()-(ly-lz)
z_min, z_max = vertices[:,2].min(), vertices[:,2].max()

# Write LAMMPS data file
with open(output_file1, 'w') as f:
    # Header
    f.write("LAMMPS data file from Python script\n\n")
    
    f.write(f"{num_atoms} atoms\n")
    f.write(f"{num_atom_types} atom types\n\n")
    
    # Box dimensions with tilt factors
    f.write(f"{x_min:.6f} {x_max:.6f} xlo xhi\n")
    f.write(f"{y_min:.6f} {y_max:.6f} ylo yhi\n")
    f.write(f"{z_min:.6f} {z_max:.6f} zlo zhi\n")
    f.write(f"{xy:.6f} {xz:.6f} {yz:.6f} xy xz yz\n\n")
    
    # Atoms section
    f.write("Atoms\n\n")
    
    # Write specified atoms first
    written_atoms = set()
    for i, index in enumerate(fix_indices, 1):
        atom = slected_data[index]
        atom_id = i
        atom_type = int(atom[1]) + 1  # Shifting atom types by 1 as LAMMPS uses 1-based indexing
        x, y, z = atom[2:5]
        f.write(f"{atom_id} {atom_type} {x:.6f} {y:.6f} {z:.6f}\n")
        written_atoms.add(index)
    
    # Write the rest of the atoms
    for i, atom in enumerate(slected_data):
        if i not in written_atoms:
            atom_id = len(written_atoms) + 1
            atom_type = int(atom[1]) + 1  # Shifting atom types by 1 as LAMMPS uses 1-based indexing
            x, y, z = atom[2:5]
            f.write(f"{atom_id} {atom_type} {x:.6f} {y:.6f} {z:.6f}\n")
            written_atoms.add(i)

print("LAMMPS data file 'lammps_data.dat' has been created with specified atom order.")

with open(output_file2, 'w') as f:
    # Header
    f.write(f"{nearest_atom[2:5][0]} {nearest_atom[2:5][1]} {nearest_atom[2:5][2]}")