import sys

def convert_dump_to_cfg(dump_file, cfg_file):
    with open(dump_file, 'r') as f:
        lines = f.readlines()

    print(f"Reading from {dump_file}")

    # Extract number of atoms
    num_atoms = int(lines[3].split()[0])
    print(f"Number of atoms: {num_atoms}")

    # Prepare output to write to cfg file
    with open(cfg_file, 'w') as f:
        f.write("BEGIN_CFG\n")
        f.write(f" Size\n    {num_atoms}\n")
        f.write(" AtomData:  id type       cartes_x      cartes_y      cartes_z\n")

        # Extract atom data and write to cfg file
        i = 1
        for line in lines[9:]:
            if line.strip().startswith("ITEM:"):
                break
            if line.strip() == "":
                continue
            atom_info = line.split()
            atom_id = i
            atom_type = int(atom_info[1]) - 1
            x = float(atom_info[2])
            y = float(atom_info[3])
            z = float(atom_info[4])
            f.write(f"{'{:>7}'.format(atom_id)}{'{:>5}'.format(atom_type)}")
            f.write(f"{'{:>14.6f}'.format(x)}{'{:>14.6f}'.format(y)}{'{:>14.6f}'.format(z)}\n")
            i += 1

        f.write("END_CFG\n")

    print(f"Conversion complete: {cfg_file}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <file_index>")
        sys.exit(1)

    p = int(sys.argv[1])
    lammps_dump_path = f"./relax_{p}.dump"
    output_cfg_file = f"./relax_{p}.cfg"
    convert_dump_to_cfg(lammps_dump_path, output_cfg_file)
    print(f'{lammps_dump_path} has been converted to {output_cfg_file}')

