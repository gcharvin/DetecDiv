# DetecDiv Windows installation guide

This guide describes a complete DetecDiv installation on Windows and includes
the additional assets required by the Pomegranate pipeline. The common sections
are intended to become the basis of a generic DetecDiv installation guide.

## 1. Supported setup

- Windows 10 or Windows 11, 64 bit
- MATLAB R2021a or newer
- DetecDiv repository branch: `unstable`
- DetecDiv-plugins repository branch: `main`
- Local Python execution through the dedicated Conda environment
  `detecdiv_python`

Use this installation root throughout the procedure:

```text
C:\Users\<WindowsUser>\Documents\DetecDivWorkspace\
|-- code\
|   |-- DetecDiv\
|   `-- DetecDiv-plugins\
|-- assets\
|   |-- pipelines\detecdiv_pomegranate\
|   `-- models\pombe_seg_1\
|-- data\raw\
|-- projects\
`-- downloads\
```

Create `DetecDivWorkspace` and its `code`, `assets`, `data`, `projects`, and
`downloads` parent folders first. GitHub Desktop creates the two repository
folders during cloning.

## 2. Install MATLAB and all required MathWorks products

Install MATLAB R2021a or newer with all seven products required by DetecDiv:

1. MATLAB
2. Computer Vision Toolbox
3. Deep Learning Toolbox
4. Database Toolbox
5. Image Processing Toolbox
6. Parallel Computing Toolbox
7. Statistics and Machine Learning Toolbox

Start MATLAB once and verify the installation:

```matlab
ver
```

All seven products are required for a complete DetecDiv installation, even if
a particular pipeline does not exercise every feature.

## 3. Create a GitHub account and install GitHub Desktop

1. Open <https://github.com/signup>.
2. Create a personal GitHub account and verify the email address.
3. Enable two-factor authentication and store the recovery codes safely.
4. Install GitHub Desktop from <https://desktop.github.com/>.
5. Open GitHub Desktop.
6. Select **File > Options > Accounts > Sign in to GitHub.com**.
7. Complete the browser authorization and return to GitHub Desktop.

## 4. Clone the repositories with GitHub Desktop

### 4.1 DetecDiv

1. Select **File > Clone repository**.
2. Open the **URL** tab.
3. Enter `https://github.com/gcharvin/DetecDiv.git`.
4. Set the local path to:
   `C:\Users\<WindowsUser>\Documents\DetecDivWorkspace\code\DetecDiv`.
5. Click **Clone**.
6. Open **Current branch** and select `unstable`.
7. Click **Fetch origin**, then **Pull origin** if offered.

### 4.2 DetecDiv plugins

1. Select **File > Clone repository** again.
2. Open the **URL** tab.
3. Enter `https://github.com/gcharvin/DetecDiv-plugins.git`.
4. Set the local path to:
   `C:\Users\<WindowsUser>\Documents\DetecDivWorkspace\code\DetecDiv-plugins`.
5. Click **Clone**.
6. Keep the `main` branch selected.
7. Click **Fetch origin**, then **Pull origin** if offered.

Verify these locations:

```text
...\code\DetecDiv\startup.m
...\code\DetecDiv\engine\classification\+cellposesam\
...\code\DetecDiv-plugins\plugins\processor\
```

## 5. Install Miniconda for Windows

1. Download the 64-bit Windows Miniconda installer from
   <https://docs.conda.io/projects/miniconda/>.
2. Install it for the current user and keep the default installation folder.
3. Open Anaconda Prompt and run:

```powershell
conda --version
conda info --base
```

4. Close Anaconda Prompt and restart MATLAB.

Do not create a Python environment manually. Miniconda is the only Python
component installed directly by the user.

## 6. Initialize DetecDiv in MATLAB

```matlab
cd('C:\Users\<WindowsUser>\Documents\DetecDivWorkspace\code\DetecDiv')
startup
which runPipeline
which cellposesam.classify
```

Register the external plugin repository:

```matlab
detecdiv_plugins_register_root( ...
    'C:\Users\<WindowsUser>\Documents\DetecDivWorkspace\code\DetecDiv-plugins')
detecdiv_plugins_addpath
detecdiv_plugins_list
```

For the Pomegranate pipeline, verify the three processor packages:

```matlab
which bestFocusPlane.process
which detectViterbiPombeDivisionFrame.process
which detecdivPomegranate.process
```

## 7. Create the dedicated Python environment

Run this command once from MATLAB:

```matlab
info = select_and_load_conda_env( ...
    'backend', 'local', ...
    'mode', 'default', ...
    'debug', true);
```

DetecDiv automatically:

- finds Conda;
- creates `detecdiv_python` with Python 3.10;
- detects NVIDIA hardware;
- installs the appropriate PyTorch 2.7.0 GPU or CPU build;
- installs Cellpose 4.2.1.1, Zarr, Trackastra 0.5.3, and their dependencies;
- repairs the known Windows OpenMP/NumPy conflict when detected;
- loads Python into MATLAB with `pyenv` in `OutOfProcess` mode;
- verifies the package imports used by DetecDiv runners.

Verify the result:

```matlab
pe = pyenv;
disp(pe)
disp(info.torch)
py.importlib.import_module('torch');
py.importlib.import_module('cellpose.models');
```

Expected results:

- `pyenv.Status` is `Loaded`;
- `pyenv.ExecutionMode` is `OutOfProcess`;
- both import commands complete without an error.

Rerunning `select_and_load_conda_env` is safe. It reuses a healthy environment
and only installs or repairs missing components.

## 8. Install the Pomegranate pipeline assets

The model and pipeline archives are distributed separately from Git because
the CellposeSAM model archive is approximately 1.5 GB.

Copy these files to `DetecDivWorkspace\downloads`:

- `detecdiv_pomegranate_pipeline.zip`
- `pombe_seg_1_cellposesam_model.zip`
- `SHA256SUMS.txt`

Extract the pipeline archive into:

```text
C:\Users\<WindowsUser>\Documents\DetecDivWorkspace\assets\pipelines
```

Verify:

```text
...\assets\pipelines\detecdiv_pomegranate\pipeline.json
```

Extract the model archive into:

```text
C:\Users\<WindowsUser>\Documents\DetecDivWorkspace\assets\models
```

Verify:

```text
...\assets\models\pombe_seg_1\pombe_seg_1_best.pth
...\assets\models\pombe_seg_1\models\pombe_seg_1
```

## 9. Create a Pomegranate run

Do not reuse a `run.json` created on another computer. Run files contain
computer-specific absolute paths.

1. Start MATLAB and run `startup` from the DetecDiv repository folder.
2. Enter `detecdiv` in the MATLAB Command Window.
3. Open
   `DetecDivWorkspace\assets\pipelines\detecdiv_pomegranate\pipeline.json`.
4. Create a new DetecDiv project under `DetecDivWorkspace\projects`.
5. Select the raw microscopy folder under `DetecDivWorkspace\data\raw`.
6. Create a new pipeline run and choose local execution.
7. Link `classifier_cellposesam_5` to
   `DetecDivWorkspace\assets\models\pombe_seg_1`.
8. Set the Pomegranate output directory inside the current project folder.
9. Validate the pipeline or perform a dry-run.
10. Test one FOV, one ROI, and a small frame range before processing the full
    dataset.

Expected outputs include:

- `DIC_focus` and `DIC_focus_best_z` from `bestFocusPlane`;
- `results_cellposeSAM_cell` from CellposeSAM;
- `cell_of_interest`, `pombe_division_profile`, and
  `pombe_division_score` from division tracking;
- `cell_information`, CSV files, an Excel workbook, and QC images from the
  Pomegranate exporter.

## 10. Troubleshooting

### Conda is not found

Open Anaconda Prompt, run `conda info --base`, restart MATLAB, and rerun
`select_and_load_conda_env`.

### The wrong Python runtime is already loaded

Close MATLAB completely, reopen it, run `startup`, and rerun the Python setup
command.

### The GPU is not available

Run `nvidia-smi` in Windows Terminal and update the NVIDIA driver. CPU
execution remains available.

### A processor package is missing

Repeat the plugin registration commands and verify the package with `which`.

### The model file is missing

Re-extract the model archive and link the classifier node to the
`pombe_seg_1` folder, not directly to the `.pth` file.

### A path contains another user's name

Create a new run and reselect the raw data, project, model, and output folders
on the current computer.

### CellposeSAM fails

Collect `runner_stdout.txt`, `runner_stderr.txt`, and `runner_live.log` from the
run's `work\cellposesam` folder.

## 11. Acceptance checklist

- [ ] All seven MathWorks products are listed by `ver`.
- [ ] Both repositories are under `DetecDivWorkspace\code` on the correct
      branches.
- [ ] MATLAB finds the three Pomegranate processor packages.
- [ ] `detecdiv_python` is loaded in `OutOfProcess` mode.
- [ ] `torch` and `cellpose.models` import successfully.
- [ ] The pipeline and model are under `DetecDivWorkspace\assets`.
- [ ] A new local run was created instead of reusing a foreign `run.json`.
- [ ] A short test produced the segmentation mask and Pomegranate outputs.

When requesting support, include the MATLAB release, complete `ver` output,
the `select_and_load_conda_env` debug output, `pyenv`, `info.torch`, repository
branches and commits, the new `run.json`, and the three CellposeSAM runner log
files.
