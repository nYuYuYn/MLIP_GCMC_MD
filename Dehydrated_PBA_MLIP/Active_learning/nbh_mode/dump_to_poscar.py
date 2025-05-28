import sys

def parse_lammps_dump(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()

    atoms = []
    box_bounds = []
    atom_section = False

    for line in lines:
        if "ITEM: TIMESTEP" in line:
            timestep = int(lines[lines.index(line) + 1].strip())
        elif "ITEM: NUMBER OF ATOMS" in line:
            num_atoms = int(lines[lines.index(line) + 1].strip())
        elif "ITEM: BOX BOUNDS" in line:
            for i in range(3):
                box_bounds.append(list(map(float, lines[lines.index(line) + 1 + i].strip().split())))
        elif "ITEM: ATOMS" in line:
            atom_section = True
        elif atom_section:
            atoms.append(list(map(float, line.strip().split())))

    return {
        "timestep": timestep,
        "num_atoms": num_atoms,
        "box_bounds": box_bounds,
        "atoms": atoms
    }

def lammps_dump_to_poscar(data, atom_types, output_file):
    num_atoms = data["num_atoms"]
    atoms = data["atoms"]
    box_bounds = data["box_bounds"]

    xlo, xhi = box_bounds[0][:2]
    ylo, yhi = box_bounds[1][:2]
    zlo, zhi = box_bounds[2][:2]

    lx = xhi - xlo
    ly = yhi - ylo
    lz = zhi - zlo

    a = [lx, 0, 0]
    b = [0, ly, 0]
    c = [0, 0, lz]

    atom_count = {atom: 0 for atom in atom_types}
    atom_positions = {atom: [] for atom in atom_types}

    for atom in atoms:
        atom_id, atom_type, x, y, z = atom
        atom_type = int(atom_type)
        atom_positions[atom_types[atom_type - 1]].append([x, y, z])
        atom_count[atom_types[atom_type - 1]] += 1

    with open(output_file, 'w') as file:
        file.write("Converted from LAMMPS dump file\n")
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
    atom_types = ["C", "Mn", "Fe", "N", "Na"]  # Example atom types
    lammps_file_path = f"./relaxed.dump{p}"
    output_poscar_file = f"POSCAR{p}"
    data = parse_lammps_dump(lammps_file_path)
    lammps_dump_to_poscar(data, atom_types, output_poscar_file)
    print(f'{lammps_file_path} has been converted to {output_poscar_file}')

