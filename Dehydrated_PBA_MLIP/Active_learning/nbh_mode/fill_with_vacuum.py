import sys
import numpy as np
p = int(sys.argv[1])
name = "POSCAR" + str(p)      
Input = open(name, "r")
print("fill with vacuum for " + name + " is starting!" )
is_skipped_first_line = False
is_factor_read = False
n_read_lattice_vectors = 0
is_size_read = False
is_coordinates_read = False
is_skipped_cart_line = False
current_type = 0
current_atom = 0
saved_atoms = 0

Factor = 1
Supercell = [] 
Ntypes = 0
Natoms_per_type = [] 
Natoms = 0
Coordinates = [] 
Types = []

for line in Input:
    buffer = line.split()
    if (is_skipped_first_line == False):
        is_skipped_first_line = True
        continue
    if (is_factor_read == False):
        Factor = int(buffer[0])
        is_factor_read = True
        continue
    if (n_read_lattice_vectors != 3):
        x = Factor * float(buffer[0])
        y = Factor * float(buffer[1])
        z = Factor * float(buffer[2])
        Supercell.append([x, y, z])
        n_read_lattice_vectors += 1
        continue
    if (is_size_read == False):
        Ntypes = len(buffer)
        for i in range(0,Ntypes):
            Natoms_per_type.append(int(buffer[i]))
            Natoms += Natoms_per_type[i]
        is_size_read = True
        continue
    if (is_skipped_cart_line == False):
        is_skipped_cart_line = True
        continue
    if (is_coordinates_read == False):
        x = float(buffer[0])
        y = float(buffer[1])
        z = float(buffer[2])
        Coordinates.append([x, y, z])
        Types.append(current_type)
        if (current_atom-saved_atoms == Natoms_per_type[current_type]-1):
            saved_atoms += Natoms_per_type[current_type]
            current_type += 1
        current_atom += 1
        if (current_atom == Natoms):
            is_coordinates_read = True
        continue

min_x = Coordinates[0][0]
max_x = Coordinates[0][0]
min_y = Coordinates[0][1]
max_y = Coordinates[0][1]
min_z = Coordinates[0][2]
max_z = Coordinates[0][2]

for i in range(1,Natoms):
    if (Coordinates[i][0] < min_x):
        min_x = Coordinates[i][0]
    if (Coordinates[i][0] > max_x):
        max_x = Coordinates[i][0]
    if (Coordinates[i][1] < min_y):
        min_y = Coordinates[i][1]
    if (Coordinates[i][1] > max_y):
        max_y = Coordinates[i][1]
    if (Coordinates[i][2] < min_z):
        min_z = Coordinates[i][2]
    if (Coordinates[i][2] > max_z):
        max_z = Coordinates[i][2]

for i in range(0,Natoms):
    Coordinates[i][0] -= min_x
    Coordinates[i][1] -= min_y
    Coordinates[i][2] -= min_z

vacuum = 9
Supercell[0][0] = max_x - min_x + vacuum
Supercell[1][1] = max_y - min_y + vacuum
Supercell[2][2] = max_z - min_z + vacuum

name_output = "POSCAR_output" + str(p)
Output = open(name_output, "w")
Output.write("MLIP output to VASP" + '\n')
Output.write("1" + '\n')
for i in range(0,3):
    Output.write('\t' + str(Supercell[i][0]) + '\t' + str(Supercell[i][1]) + '\t' + str(Supercell[i][2]) + '\n')
for i in range(0,Ntypes):
    Output.write(' ' + str(Natoms_per_type[i]))
Output.write('\n')
Output.write("cart" + '\n')
for i in range(0,Natoms):
    Output.write('\t' + str(Coordinates[i][0]) + '\t' + str(Coordinates[i][1]) + '\t' + str(Coordinates[i][2]) + '\n')

