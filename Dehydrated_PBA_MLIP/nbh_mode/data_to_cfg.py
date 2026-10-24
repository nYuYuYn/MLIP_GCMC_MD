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

def lammps_to_cfg(data, atom_types, output_file):
    num_atoms = data["num_atoms"]
    atoms = data["atoms"]

    with open(output_file, 'w') as file:
        file.write("BEGIN_CFG\n")
        file.write(" Size\n")
        file.write(f"    {num_atoms}\n")
        file.write(" AtomData:  id type       cartes_x      cartes_y      cartes_z\n")

        for atom in atoms:
            atom_id = int(atom[0])
            atom_type = int(atom[1])-1
            x, y, z = map(float, atom[2:5])
            file.write(f"    {atom_id}    {atom_type}    {x:.6f}    {y:.6f}    {z:.6f}\n")

        file.write("END_CFG\n")

if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("Usage: python script.py <file_index>")
        sys.exit(1)

    p = int(sys.argv[1])
    atom_types = ["C", "Mn", "Fe", "N", "Na"]  # Placeholder for future use if needed
    lammps_file_path = f"./nbh.data{p}"
    output_cfg_file = f"section_{p+1}.cfg"
    data = parse_lammps_data(lammps_file_path)
    lammps_to_cfg(data, atom_types, output_cfg_file)
    print(f'{lammps_file_path} has been converted to {output_cfg_file}')

