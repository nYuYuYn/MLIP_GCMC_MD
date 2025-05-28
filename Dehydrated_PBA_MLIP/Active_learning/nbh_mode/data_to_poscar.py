import sys

def parse_lammps_data(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()

    data = {}
    reading_atoms = False
    atoms = []

    for line in lines:
        if "atoms" in line:
            data["num_atoms"] = int(line.split()[0])
        elif "xlo xhi" in line:
            data["xlo"], data["xhi"] = map(float, line.split()[:2])
        elif "ylo yhi" in line:
            data["ylo"], data["yhi"] = map(float, line.split()[:2])
        elif "zlo zhi" in line:
            data["zlo"], data["zhi"] = map(float, line.split()[:2])
        elif "Atoms" in line:
            reading_atoms = True
        elif reading_atoms and line.strip():
            atoms.append(line.split())

    data["atoms"] = atoms
    return data

def lammps_to_poscar(data, atom_types, output_file):
    num_atoms = data["num_atoms"]
    atoms = data["atoms"]

    xlo, xhi = data["xlo"], data["xhi"]
    ylo, yhi = data["ylo"], data["yhi"]
    zlo, zhi = data["zlo"], data["zhi"]

    lx = xhi - xlo
    ly = yhi - ylo
    lz = zhi - zlo

    # Assuming orthogonal box
    a = [lx, 0, 0]
    b = [0, ly, 0]
    c = [0, 0, lz]

    atom_count = {atom: 0 for atom in atom_types}
    atom_positions = {atom: [] for atom in atom_types}

    for atom in atoms:
        atom_type = int(atom[1])-1
        x, y, z = map(float, atom[2:5])
        atom_positions[atom_types[atom_type - 1]].append([x, y, z])
        atom_count[atom_types[atom_type - 1]] += 1

    with open(output_file, 'w') as file:
        file.write("Converted from LAMMPS data file\n")
        file.write("1.0\n")
        file.write(f"    {a[0]:.6f} {a[1]:.6f} {a[2]:.6f}\n")
        file.write(f"    {b[0]:.6f} {b[1]:.6f} {b[2]:.6f}\n")
        file.write(f"    {c[0]:.6f} {c[1]:.6f} {c[2]:.6f}\n")

        file.write(" ".join(atom_types) + "\n")
        file.write(" ".join(map(str, [atom_count[atom] for atom in atom_types])) + "\n")
        file.write("Cartesian\n")

        for atom in atom_types:
            for pos in atom_positions[atom]:
                file.write(f"{pos[0]:.6f} {pos[1]:.6f} {pos[2]:.6f}\n")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <file_index>")
        sys.exit(1)

    p = int(sys.argv[1])
    atom_types = ["C", "Mn", "Fe", "N", "Na"]
    lammps_file_path = f"./relaxed.data{p}"
    output_poscar_file = f"POSCAR{p}"
    data = parse_lammps_data(lammps_file_path)
    lammps_to_poscar(data, atom_types, output_poscar_file)
    print(f'{lammps_file_path} has been converted to {output_poscar_file}')
