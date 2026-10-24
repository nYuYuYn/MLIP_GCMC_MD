import re
import numpy as np
import os
from lammps import lammps
from mpi4py import MPI

def parse_print_file(file_path):
    data = {'Step': [], 'atoms': []}
    with open(file_path, 'r') as file:
        for line in file:
            if re.match(r"^\s*Step\s+Atoms", line):
                next(file)  # Skip the header line
                for data_line in file:
                    if re.match(r"^\s*\d+", data_line) and len(data_line.split()) == 2:
                        values = data_line.split()
                        data['Step'].append(int(values[0]))
                        data['atoms'].append(float(values[1]))
                    else:
                        break
    return data

def detect_equilibration_from_log(fname, precision=10, window_fraction=0.2):
    """Only called on rank 0."""
    log = parse_print_file(fname)
    step = np.array(log['Step'])
    n_Na = np.array(log['atoms']) - 28672
    w = int(len(step) * window_fraction)
    means, stds = [], []

    for blk in range(int(1 / window_fraction)):
        s, e = blk * w, (blk + 1) * w
        if e > len(n_Na):
            break
        means.append(np.mean(n_Na[s:e]))
        stds.append(np.std(n_Na[s:e]))

    means = np.array(means)
    stds = np.array(stds)
    diffs = np.abs(means[1:] - means[:-1])
    std_sums = stds[:-1] + stds[1:]

    pre1 = np.std(n_Na) > 10
    pre2 = diffs[-1] > 8
    c1 = diffs[-1] < precision
    c2 = std_sums[-1] < 5
    c3 = diffs.argmin() == len(diffs) - 1
    c4 = std_sums.argmin() == len(std_sums) - 1

    if pre1 and pre2:
        if c1 and c2 and c3 and c4:
            skip_loop = 1
            return True, skip_loop
        else:
            skip_loop = 0
            return False, skip_loop
    else:
        skip_loop = 1
        return True, skip_loop

def check_equilibrium_lmp(lammps_ptr):
    """LAMMPS Python interface function to check if a simulation has reached equilibrium."""
    # Write debug log as soon as function is called
    with open('py_function_called.log', 'a') as f:
        f.write(f"check_equilibrium_lmp was called!\n")
    
    # Initialize LAMMPS object and MPI communicator
    lmp = lammps(ptr=lammps_ptr)
    comm = MPI.COMM_WORLD
    rank = comm.Get_rank()
    
    # Write debug log with rank information
    if rank == 0:
        with open('py_output.log', 'a') as f:
            f.write(f"[Python] Function called on rank {rank}\n")
    
    # Default: keep running
    skip_loop = 0
    
    # Get simulation information - with error handling
    try:
        step = lmp.get_thermo("step")
        atoms = lmp.get_thermo("atoms")
        if rank == 0:
            with open('py_output.log', 'a') as f:
                f.write(f"[Python] Current step: {step}, atoms: {atoms}\n")
    except Exception as e:
        if rank == 0:
            with open('py_output.log', 'a') as f:
                f.write(f"[Python][ERROR] Failed to get thermo values: {str(e)}\n")
        return 0
    
    # Try to get the N variable
    try:
        N = int(lmp.extract_variable("N", "all", 0))
        if rank == 0:
            with open('py_output.log', 'a') as f:
                f.write(f"[Python] Current N value: {N+1}\n")
    except Exception as e:
        if rank == 0:
            with open('py_output.log', 'a') as f:
                f.write(f"[Python][ERROR] Failed to extract variable N: {str(e)}\n")
        N = 0
    
    # Try to get the M variable
    try:
        M = int(lmp.extract_variable("M", "all", 0))
        if rank == 0:
            with open('py_output.log', 'a') as f:
                f.write(f"[Python] Current M value: {M+1}\n")
    except Exception as e:
        if rank == 0:
            with open('py_output.log', 'a') as f:
                f.write(f"[Python][ERROR] Failed to extract variable M: {str(e)}\n")
        M = 0
    
    # Define reached before potential early returns
    reached = False
    
    # Early check for step threshold
    if step < 5000:  # Lowered from 10000 for debugging
        if rank == 0:
            with open('py_output.log', 'a') as f:
                f.write(f"[Python] Step {step} < 5000; skipping check.\n")
        # Broadcast the decision
        reached = comm.bcast(reached, root=0)
        return skip_loop
    
    # Rank 0 does file parsing and analysis
    if rank == 0:
        fname = f"./atoms_log_{N+1}.txt"
        with open('py_output.log', 'a') as f:
            f.write(f"[Python] Looking for log file: {fname}\n")
            
        # Check if file exists
        if os.path.exists(fname):
            with open('py_output.log', 'a') as f:
                f.write(f"[Python] File exists: {fname}\n")
        else:
            with open('py_output.log', 'a') as f:
                f.write(f"[Python][WARNING] File not found: {fname}\n")
            
        try:
            reached, skip_loop = detect_equilibration_from_log(fname)
            with open('py_output.log', 'a') as f:
                f.write(f"[Python] Analysis result: reached={reached}, skip_loop={skip_loop}\n")
        except Exception as e:
            reached = False
            skip_loop = 0
            with open('py_output.log', 'a') as f:
                f.write(f"[Python][ERROR] Error analyzing {fname}: {str(e)}\n")
                import traceback
                f.write(traceback.format_exc())
    
    # Broadcast the decision to all ranks
    reached = comm.bcast(reached, root=0)
    skip_loop = comm.bcast(skip_loop, root=0)
    
    if rank == 0:
        with open('py_output.log', 'a') as f:
            f.write(f"[Python] Final decision: reached={reached}, returning skip_loop={skip_loop}\n")
            
    return skip_loop