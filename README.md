# MnFe-PBA: Active Learning, Molecular Dynamics, and Analysis

Scripts and notebooks for training Moment Tensor Potentials (MTPs), running LAMMPS simulations, and analyzing manganese–iron Prussian blue analogues (MnFe-PBAs).

The workflow covers **active learning**, **production simulations**, **data analysis**, and **trained potentials and training sets**.

## Contents

- [Atomic species](#atomic-species)
- [Active learning](#active-learning)
- [Production simulations](#production-simulations)
- [Data analysis](#data-analysis)
- [MTPs and training sets](#mtps-and-training-sets)

## Atomic species

The system contains seven atomic species, listed in the following order:

```text
C  Mn  Fe  N  Na  O  H
```

The `remap.py` step maintains the correct species mapping for structures in which water or Na is absent.

## Active learning

Each active-learning iteration generates candidate structures with LAMMPS, selects and filters structures for DFT calculations, adds suitable DFT results to the training set, and retrains the MTP.

### Entry points

| Script | Purpose |
| --- | --- |
| `submit.sh` | Launches the workflow scripts in the background. |
| `start-run.sh` | Initiates the iterative active-learning cycles and saves the current `curr.almtp` and `train.cfg` in `pot_save/`. |
| `md_al_mtp_2.sh` | Coordinates the main active-learning workflow described below. |

### 1. Generate candidate structures

Choose one of the following LAMMPS launchers:

| Launcher | Simulation | Default parallel configuration | Submission behavior |
| --- | --- | --- | --- |
| `run_lammps_3.sh` | GCMC hydration | 40 jobs, with one core per job | The number of parallel simulations is configurable. |
| `run_lammps_2.sh` | GCMC sodiation | 8 jobs | The number of parallel simulations is configurable; jobs are submitted to different queues according to availability. |

The simulations generate the preselected structure file, `preslected.cfg`.

**Configure the completion check in `md_al_mtp_2.sh` to match the chosen launcher.** The following excerpt expects eight completion-marker files:

```bash
is_lammps_finished=0
while [ $is_lammps_finished -ne 1 ]; do
    sleep 5
    finished_jobs=$(ls is_lammps_finished_*.txt 2>/dev/null | wc -l)
    if [ "$finished_jobs" -eq 8 ]; then
        echo "All 8 LAMMPS jobs have finished successfully."
        is_lammps_finished=1
    else
        MD_cal=$(qstat 2>/dev/null | grep yy276937 | grep "MD_h2o" | wc -l)
        echo "Waiting for LAMMPS... $finished_jobs/8 completed. ($MD_cal jobs currently in queue)"
    fi
done
```

Update the following settings when changing the launcher or job count:

| Setting | Required adjustment |
| --- | --- |
| Completion threshold (`-eq 8`) | Set it to the number of completion-marker files expected for the current iteration. |
| Progress messages (`8`) | Use the same expected completion count. |
| Queue username (`yy276937`) | Replace it with the account submitting the jobs. |
| Job-name filter (`MD_h2o`) | Match the job names used by the selected launcher. |

The expected completion count must reflect the jobs launched in that iteration; a limit on concurrent jobs is not necessarily the total job count.

### 2. Select and filter structures

| Script | Task | Output |
| --- | --- | --- |
| `select.sh` | Selects informative structures from `preslected.cfg`. | `slected.cfg` |
| `radius_cutoff.py` | Removes selected structures containing interatomic distances below **0.2 Å**. The cutoff can be changed in the Python script. | `filtered_selected.cfg` |

The filenames `preslected.cfg` and `slected.cfg` retain their current spelling. Ensure that the output filename used by `select.sh` matches the input expected by the filtering step.

### 3. Prepare and run DFT calculations

For each structure in `filtered_selected.cfg`, the workflow:

1. Converts the structure into an individual POSCAR file.
2. Creates a calculation directory, numbered from `0` onward.
3. Prepares an INCAR tailored to that structure.
4. Uses `remap.py` to correct atom-type labels for structures without water or Na, where the MTP type mapping can otherwise be incorrect.
5. Runs the DFT calculation.

The number of calculation directories matches the number of structures in `filtered_selected.cfg`.

### 4. Collect DFT results and update the training set

After all DFT calculations finish:

1. Collect `calculated.cfg` from each calculation directory into `vasp.cfg`.
2. Run `clean.py` to remove structures containing interatomic forces greater than **150 eV/Å**, producing `cleaned_vasp.cfg`.
3. Append `cleaned_vasp.cfg` to `train.cfg`.

This filtering step prevents extreme-force structures from polluting the training set.

### 5. Retrain the potential

`train.sh` trains the MTP using the updated `train.cfg`. The active-learning cycle then continues with the updated potential.

## Production simulations

Production launchers generally follow this pattern:

1. A shell script generates individual LAMMPS input files from a `.my` template.
2. The launcher submits the jobs to different queues according to availability.

### Sodiation and hydration

| Calculation | Launcher | Template and input files |
| --- | --- | --- |
| Sodiation | `run_RDF.sh` | `RDF.my` |
| Hydration | `run_hydration.sh` | `hydration.my`, `hydration.data` |

### Diffusivity

| Workflow | Launcher(s) | Template |
| --- | --- | --- |
| Vacancy-containing structures | `run_vac_diff.sh` | `in_vac.my` |
| Diffusion simulations | `run_diffsion.sh`, `run_diffsion_300.sh` | `in_diffuse.my` |
| Restarted diffusion simulations | `run_restart_diffuse.sh` | `restart_diffuse.my` |

### Free energy: sodiation

| Workflow | Launcher(s) | Template |
| --- | --- | --- |
| Sodiation free-energy simulations | `run_loop_bias_300_3.sh`, `run_loop_bias_300_1.sh` | `loop_bias.my` |
| Sodiation free-energy simulations with vacancies | `run_loop_bias_vac.sh` | `loop_bias_vac.my` |

### Free energy: hydration

| Launcher(s) | Template and input files |
| --- | --- |
| `run_hydration_vac.sh`, `run_hydration.sh` | `hydration.my`, `hydration.data` |

### Vibrational density of states

| Launcher | Template |
| --- | --- |
| `run_vDOS.sh` | `vDOS.my` |

### Model fine-tuning

`train_fine_tune.sh` fine-tunes an existing MTP.

### MDANSE calculations

`./../MDANSE.sh` generates Python scripts for calculating targeted properties, including:

- Quasielastic neutron scattering (QENS).
- Vibrational density of states (vDOS).
- Van Hove functions (VHF).

## Data analysis

| Notebook | Main tasks |
| --- | --- |
| `./pot_save/monitor.ipynb` | Monitors training-set size, training error, and the final simulation timestep reached in each active-learning iteration. |
| `compute_V.ipynb` | Analyzes and plots free energy, mean-squared displacement (MSD), diffusivity, and trajectory data. |
| `validation.ipynb` | Visualizes the composition distribution of the training set, plots and analyzes training errors, and cleans the training set. |
| `MD_XRD.ipynb` | Performs coordination, radial distribution function (RDF), bond-angle, and interfacial-energy analyses. |
| `MDANSE.ipynb` | Analyzes simulation results generated by MDANSE. |

## MTPs and training sets

### Main potential and training set

| File | Description |
| --- | --- |
| **`curr_20_cfg_r02_65.almtp`** |  |
| `curr.almtp` | **Final validated MTP.**  `curr_20_cfg_r02_65.almtp` + additional active learning. |
| `train.cfg` | Main training set. |
| `curr_20_cfg_r02_55.almtp` | Additional MTP variant. |
| `curr_20_cfg_r02_60.almtp` | Additional MTP variant. |
| `curr_20_cfg_r02_70.almtp` | Additional MTP variant. |

### Fine-tuned potential and additional training set

| File | Description |
| --- | --- |
| `curr_16.almtp` | Level-16 MTP fine-tuned with respect to the force weight. |
| `train_E_0.cfg` | Additional training-set file. |
