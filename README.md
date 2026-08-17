# SIMPLE Framework

A MATLAB workflow for auditable, offline, group-level analysis of event-related EEG in an extreme low-redundancy regime.

**Associated methods paper:** [Add citation and link here when available]

## Repository overview

This repository implements a structured workflow for event-related EEG in which the core low-redundancy processing unit is one analysed event–channel instance: one event and one channel, without trial averaging or multichannel redundancy. Group-level inference is a separate design layer and requires either one prespecified participant-level contribution or a method that accounts for repeated observations. In this regime, preprocessing choices, epoch definition, screening decisions, and dataset-level plausibility checks become unusually important.

The repository is written in MATLAB and is organised as a five-step workflow:

1. **proc** – inspect raw data and create processed, epoched datasets
2. **quant** – extract quality-control and response features
3. **sum** – export and pool summaries
4. **screen** – perform explicit, auditable epoch–channel screening
5. **check** – run post-screening plausibility checks

These five stages correspond directly to Steps 3–7 in `simple-oxford` and
`simple-strasbourg`:

| `simple-framework` | `simple-oxford` / `simple-strasbourg` |
| --- | --- |
| Step 1: `proc` | Step 3 |
| Step 2: `quant` | Step 4 |
| Step 3: `sum` | Step 5 |
| Step 4: `screen` | Step 6 |
| Step 5: `check` | Step 7 |

The dataset-specific repositories document their own import and group-analysis
stages. This README provides the detailed reference for the shared five-stage
framework.

## What this repository is for

This repository is for:

- offline analysis of event-related EEG
- group-level inference
- settings with very limited within-participant redundancy
- sparse channel configurations
- workflows where transparent preprocessing, screening, and post-screening checks are part of the inferential logic

A central use-case is neonatal noxious-event EEG, but the workflow is designed around the broader constraint structure rather than a single application domain alone.

## What this repository is not for

This repository is not intended to be:

- a general-purpose EEG toolbox
- a real-time or online analysis system
- a subject-level diagnostic or predictive tool
- a generic multichannel ERP pipeline
- a one-click workflow with no user judgement or inspection points

## How to approach this repository

This repository is best understood as a **staged workflow with defined user intervention points**, not as a single script to run from start to finish without inspection.

Before running the scripts, read:

- **Before you begin**
- **Core input and configuration files**
- **Workflow overview**
- **Points where user input or inspection is required**

Several steps require you to inspect generated outputs, edit configuration files, or make explicit screening decisions before moving on.

## Repository structure

Data, logs, generated outputs, screening decisions, and downstream analysis
files are local working materials excluded from version control. A fresh clone
contains an empty `data/` and `data_lists/` through tracked `.gitkeep` files,
plus the workflow code, bundled templates, configuration, tests and
documentation.

`data/` and `data_lists/` are deliberately present through tracked `.gitkeep`
files; generated descendants remain local.

### `data_lists/`

Core metadata and configuration files used by the workflow.

`dataset_list.csv` and any other CSV/XLSX project lists are local and ignored.
The tracked NRF configuration is under `NRFs/`, not this directory.

### `functions/`

MATLAB helper functions and utility code used by the runnable scripts.

The repository is self-contained: this directory includes `preproc`,
`quality_control_features` and its 11 `calc_*` functions,
`estimate_response`, `jittercorrect`, `NRFUtils`, event helpers, averaging and
post-screening helpers.

### `NRFs/`

Six bundled NRF templates at 500 Hz and 2,000 Hz, together with the tracked
`nrf_config.ini`. Logical template names resolve only against this directory;
explicit canonical MAT-file paths are also supported where documented. The
MATLAB path is not used to discover templates.

- `early_NRF_500Hz.mat`
- `early_NRF_2000Hz.mat`
- `noxious_NRF_500Hz.mat`
- `noxious_NRF_2000Hz.mat`
- `noxious_preterm_NRF_500Hz.mat`
- `noxious_preterm_NRF_2000Hz.mat`

The principal APIs are `preproc(EEG, options)`,
`estimate_response(EEG, options)`, `jittercorrect`,
`quality_control_features` and `add_offset_events`. The shipped profiles define
the demonstrator's exact `Cz` channel and term-foot NRF post start of 400 ms;
profile values are project configuration rather than universal SIMPLE defaults.

### `scripts/`

Runnable MATLAB scripts organised into the five workflow stages.

This folder also contains `log_command_window.m`, which is used by the scripts to write per-script log files.

### `data/info/`

Intermediate audit and inventory outputs, such as summaries of:

- event types
- channel labels
- epoch types
- multi-event epochs

These outputs are intended for inspection and quality checks during the workflow.

### `data/summary/`

Per-dataset and pooled summary outputs, then screening outputs and post-screening outputs.

### `tests/`

Synthetic regression fixtures, the complete MATLAB test runner and a finite
static/Git verifier. These tests use synthetic fixtures and do not require or
inspect real EEG data.

### `data/logs/`

Ignored per-script Command Window logs written by `log_command_window.m`.

## Before you begin

### Software requirements

This repository assumes access to:

- **MATLAB**
- **EEGLAB**
- the MATLAB toolboxes required by the specific functions you use

The currently verified producing environment is MATLAB R2026a Update 4 with
EEGLAB 2026.0.0. The complete regression suite additionally exercises required
dependencies including `corr`, `robustfit`, `fgls` and EEGLAB functions.
CleanLine is optional; the notch-filter route is available when it is not
selected.

### Expected input data

The workflow expects EEG datasets stored as EEGLAB `.set` files. For each dataset, `data_lists/dataset_list.csv` supplies the project-relative raw-data path in `path_raw` and the `.set` filename in `EEGfile_raw`. Subject, session, and run identifiers are held separately in the `subjectID`, `sessionID`, and `runID` columns; the scripts do not infer those identifiers from a strict filename convention.

Raw paths should begin with `data/raw`, because the workflow derives processed paths by replacing that leading component with `data/processed`.

For example, one row could specify:

```text
subjectID,sessionID,runID,path_raw,EEGfile_raw
001,01,01,data/raw/sub-001/ses-01/eeg,sub-001_ses-01_run-01_eeg.set
```

### Path editing

Do not edit a personal absolute project path into the scripts. All 21 runnable
scripts resolve the project root from their own direct membership in this
repository's `scripts/` directory and fail closed if that relationship or the
required repository-local helpers cannot be established. Event, channel, NRF,
time-window, and output-name settings remain explicit configuration and must be
reviewed deliberately for any project other than the demonstrator described
below.

### Running scripts from the `scripts` folder

It is recommended to run the workflow from within the `scripts` folder, or otherwise ensure that `scripts/` is on the MATLAB path.

This matters because the helper `log_command_window.m` lives in `scripts/` and is called at the start and end of the runnable scripts.

## Fixed synthetic-demonstrator route

This repository is configured for the Simple Paper synthetic demonstrator. Its
input contract is deliberately narrow:

- 31 synthetic subjects, `001` through `031`, with session `01` and run `01`
- one 30-second, 1,000-Hz recording per subject
- one exact channel label, `Cz`
- one exact `stimulus` event at 15 seconds (EEGLAB latency 15001)
- one self-contained, one-file `.set` per recording and no `.fdt` files
- one row per recording in `data_lists/dataset_list.csv`, with project-relative
  `data/raw/...` paths and no absolute or external input location

Step 1.4 creates the exact internal-reference event `stimulus_prestim` at
−1,500 ms from `stimulus`. The processing, QC, screening and Step 5 numerical
settings define the demonstrator profile used by the scripts.

After Step 2.2, inspect the event/channel/epoch inventories and edit the
generated `data/info/epoch_types/epoch_type_summary.csv` as follows before
Step 2.3:

| `Type` | `early_NRF` | `noxious_NRF` | `noxious_preterm_NRF` |
| --- | --- | --- | --- |
| `stimulus` | `term_foot_early` | `term_foot_nox` | blank |
| `stimulus_prestim` | `term_foot_early` | `term_foot_nox` | blank |

The public `early_NRF_500Hz.mat` and `noxious_NRF_500Hz.mat` templates are
bundled under `NRFs/`. NRF consumers bind logical names to that repository-local
directory and fail closed if a template is missing or malformed; plotting code
that documents explicit-path support binds the exact canonical file supplied.
These templates are analysis dependencies only. They are not generator inputs,
and their fitted outputs are tutorial template-conditioned measurements rather
than biological or pain validation.

The expected pre-screening route has 62 epoch–channel items and 124 NRF rows.
Screening remains manual: subject 31's true `stimulus` item contains the
declared artefact and is the expected sole exclusion, but no script applies
that decision automatically. If the displayed evidence does not support that
decision, stop rather than forcing the expected count.

### One-script transaction and stop points

Run one unchanged script at a time from `scripts/`. After each script succeeds,
errors, or is cancelled, stop and inspect its log and the stated checkpoint
before selecting the next script:

| Script | Stop and check |
| --- | --- |
| Step 1.1 event types | 31 inputs; only the declared raw event labels |
| Step 1.2 channels | 31 inputs; exact sole channel `Cz` |
| Step 1.3 processed paths | every derived path remains under `data/processed` |
| Step 1.4 preprocessing | 31 self-contained processed sets; exact two epoch types and provenance |
| Step 2.1 QC | all nine configured QC values are present and finite for both items per subject |
| Step 2.2 epochs | exact `stimulus`/`stimulus_prestim` inventory; no unexpected multi-event epoch |
| Step 2.3 NRF | approve the mapping table above first; then verify 124 stored fits |
| Step 3.1 summary paths | every path remains under `data/summary` |
| Step 3.2 individual summaries | 31 complete four-file summary groups |
| Step 3.3 pooled summaries | 62 QC rows, 124 NRF rows, 31 manifest rows and 31 epoch structures |
| Step 3.4 pooled plots | inspect all 31 true `stimulus` items; do not save figures |
| Step 4.1 package | one immutable 62-item schema-v2 package; do not rerun |
| Step 4.2 viewer | screen manually; explicitly state when iterative review is complete |
| Step 4.3 apply decisions | exact decision binding and exclusion propagation; expected 61 retained items |
| Step 5.1 excluded figures | one complete rollback-safe excluded-image batch |
| Step 5.2 included epochs | inspect every retained true item and configured overlays |
| Step 5.3 average time series | inspect simple-mean trace and early/noxious overlays |
| Step 5.4 average time–frequency | inspect the fixed 3–30-Hz, mean-baseline view |
| Step 5.5 average PSD | inspect the fixed post-stimulus multitaper view |
| Step 5.6 QC separation | verify 30 complete `stimulus - stimulus_prestim` pairs and schema-v2 result |
| Step 5.7 NRF separation | verify the same 30 pairs for noxious `fglsCoef` and schema-v2 result |

The expected counts are verification checkpoints, not instructions to repair,
exclude, or reinterpret data until a count matches. A mismatch stops the route
and is investigated as evidence.

### Logging

Each runnable script starts and stops Command Window logging via `log_command_window('start')` and `log_command_window('stop')`.

This creates a per-script log file in `data/logs/`, which is useful for:

- reviewing warnings and errors later
- checking what happened during a run
- preserving an audit trail of script output

## Core input and configuration files

### `data_lists/dataset_list.csv`

This is the central workflow registry. It is both an input file and a file that is progressively updated by the workflow.

It records dataset identifiers and file paths, and later gains additional derived columns such as:

- `event_types`
- `channels`
- `path_processed`
- `EEGfile_processed`
- `epoch_types`
- `path_summary`

The workflow assumes that this file correctly points to the raw and processed datasets used in each stage.

### `NRFs/nrf_config.ini`

This file defines named NRF extraction profiles.

Each profile specifies:

- the NRF template name
- baseline length
- jitter
- channel labels
- one fitting-window start in `projectionTimes_pre` or
  `projectionTimes_post`, with the other left empty

The defaults in this file are the recommended settings for the current workflow, although advanced users may modify them if needed.

### `data/info/epoch_types/epoch_type_summary.csv`

This file is generated during Step 2 and then manually edited before NRF extraction.

It contains epoch types discovered in the processed data, plus mapping columns for NRF families:

- `early_NRF`
- `noxious_NRF`
- `noxious_preterm_NRF`

Before running NRF extraction, you must populate one or more of these columns with valid profile names from `nrf_config.ini`.

Rows or whole columns can be left blank if you do not want to fit that NRF family to those event types.

## Workflow overview

The workflow proceeds through five practical stages:

1. inspect and preprocess raw data
2. quantify QC and response features
3. export per-dataset summaries and pooled outputs
4. screen epoch–channel items explicitly
5. check whether the screened data behave plausibly

## Conceptual framework and how the workflow maps onto it

The workflow maps onto the broader framework as follows.

### Prerequisites

Mainly implemented by **Step 1**.

This stage establishes comparability across recordings through data audit, preprocessing, standardised epoching, and output conventions.

### Core Workflow

Implemented mainly by **Steps 1–4**.

This includes:

- defining true and internal-reference epochs
- quantifying quality
- quantifying response
- explicit auditable screening

### Post-core Guardrails

Implemented by **Step 5**.

This stage checks whether the screened dataset behaves plausibly before stronger interpretive claims are made.

## Step 1: processing and prerequisites

Step 1 is the practical entry point for the workflow. It audits the raw datasets, standardises them, and creates the processed epoched datasets used downstream.

Scripts:

- `step_1_proc_1_get_event_types.m`
- `step_1_proc_2_get_channels.m`
- `step_1_proc_3_add_processeds.m`
- `step_1_proc_4_preprocessing.m`

### What Step 1 does

- reads `dataset_list.csv`
- audits raw event labels
- audits raw channel labels
- derives processed output paths and filenames
- preprocesses continuous data
- deletes unwanted events where configured
- adds offset or dummy events where configured
- epochs data around true and internal-reference events
- writes provenance into processed `.set` files

### Main outputs

- updated `dataset_list.csv`
- event-type summaries in `data/info/event_types/`
- channel summaries in `data/info/channels/`
- processed `.set` files under `data/processed/`

### Relation to the framework

This stage instantiates much of the **Prerequisites** part of the framework and begins the **Core Workflow** by defining the true and internal-reference epoch structure.

### User configuration points

You should review the preprocessing options in `step_1_proc_4_preprocessing.m`, including:

- rereferencing
- resampling
- band-pass and line-noise filtering
- event deletion labels
- offset event generation
- epoch windows
- baseline correction

## Step 2: quantification

Step 2 adds the main quantitative annotations to the processed datasets.

Scripts:

- `step_2_quant_1_QC_feature_extraction.m`
- `step_2_quant_2_get_epochs.m`
- `step_2_quant_3_NRF_feature_extraction.m`

Supporting function:

- `NRFUtils.m`

### What Step 2 does

- computes epoch-level QC features for selected channels
- inventories epoch types in processed datasets
- reports multi-event epochs
- maps epoch types to NRF profiles
- fits NRF-based response features and stores them in the processed `.set` files

### Main outputs

- QC annotations inside processed `.set` files
- NRF annotations inside processed `.set` files
- `data/info/epoch_types/epoch_type_summary.csv`
- `data/info/epoch_types/multievent_epochs/`

### Relation to the framework

This stage instantiates the **quantify quality** and **quantify response** parts of the Core Workflow.

### Important user actions before NRF extraction

Before running `step_2_quant_3_NRF_feature_extraction.m`:

1. inspect the outputs in `data/info/epoch_types/multievent_epochs/`
2. check for unexpected multi-event epochs, including possible overlap between true and internal-reference epochs
3. edit `data/info/epoch_types/epoch_type_summary.csv`
4. add valid profile names from `nrf_config.ini` into:
   - `early_NRF`
   - `noxious_NRF`
   - `noxious_preterm_NRF`

NRF extraction will not do useful work unless at least one valid mapping has been defined.

## Step 3: summarisation and pooling

Step 3 exports user-selected summaries from the annotated datasets and builds pooled outputs for downstream screening and checking.

Scripts:

- `step_3_sum_1_add_summaries.m`
- `step_3_sum_2_summarise_individual.m`
- `step_3_sum_3_summarise_pooled.m`
- `step_3_sum_4_plot_epochs.m`

### What Step 3 does

- derives summary output paths
- exports per-dataset QC feature tables
- exports per-dataset NRF feature tables
- exports per-dataset epoch index files
- exports per-dataset epoch arrays
- pools those outputs across datasets
- provides pooled epoch plotting with optional NRF overlays

### Main outputs

Per dataset:

- `<stem>_qc_features.csv`
- `<stem>_nrf_features.csv`
- `<stem>_epochs_index.csv`
- `<stem>_epochs.mat`

Pooled:

- `pooled_eeg_qc_features.csv`
- `pooled_eeg_nrf_features.csv`
- `pooled_eeg_epochs.mat`
- `pooled_eeg_manifest.csv`

### Relation to the framework

This stage is best understood as a practical summarisation layer. It is not a separate conceptual stage in the framework, but it makes the QC and NRF outputs usable for screening and post-screening checks.

### Important note

`step_3_sum_2_summarise_individual.m` skips datasets with multi-event epoch labels. This is one reason the `multievent_epochs` outputs from Step 2 should be inspected before moving on.

## Step 4: auditable screening

Step 4 implements explicit epoch–channel screening as an auditable workflow.

Scripts:

- `step_4_screen_1_init_package.m`
- `step_4_screen_2_viewer_rate_epochs.m`
- `step_4_screen_3_apply_decisions.m`

### What Step 4 does

- creates an immutable screening package from pooled epochs and QC values
- opens a mouse-driven viewer for manual epoch–channel screening
- saves screening decisions atomically
- applies screening decisions to the pooled outputs

### Main outputs

- `screening_package.mat`
- `screening_decisions.mat`
- `pooled_screened_eeg_epochs.mat`
- `pooled_screened_eeg_qc_features.csv`
- `pooled_screened_eeg_nrf_features.csv`

### Relation to the framework

This stage directly instantiates the framework’s **auditable screening** component.

### Important points

- the screening unit is the **epoch–channel item**
- screening is performed on **pooled summary outputs**
- the screening package is intentionally immutable once created
- package hashes are used to ensure decisions are applied to the correct data

### Workflow order within Step 4

1. initialise the screening package
2. review and rate items in the screening viewer
3. apply decisions to create screened outputs

## Step 5: post-core guardrails

Step 5 applies post-screening visual and quantitative checks to the screened pooled data.

Scripts:

- `step_5_check_1_save_excluded_figs.m`
- `step_5_check_2_plot_included_epochs.m`
- `step_5_check_3_plot_average_ts.m`
- `step_5_check_4_plot_average_tf.m`
- `step_5_check_5_plot_average_psd.m`
- `step_5_check_6_sep_check_qc.m`
- `step_5_check_7_sep_check_nrf.m`

### What Step 5 does

- saves plots of excluded items for later review
- plots included items with optional NRF overlays
- plots group-average time series
- plots group-average time–frequency representations
- plots group-average PSDs
- performs paired QC separation checks
- performs paired NRF separation checks

### Main outputs

This stage mainly produces figures, workspace objects, console summaries, and per-script Command Window logs. Step 5.1 writes a rollback-safe, verified excluded-item PNG batch:

- `data/summary/screening/excluded_epochs/`

Steps 5.2–5.5 are display-only apart from their logs. Steps 5.6 and 5.7 atomically write machine-readable paired results using schema `simple-paired-separation-result-v2`:

- `data/summary/screening/step_5_check_6_sep_check_qc_result.mat`
- `data/summary/screening/step_5_check_7_sep_check_nrf_result.mat`

The paired checks preserve the framework's event–channel/recording-level unit, form each complete `true - internal reference` difference first, and support only the paired median or paired mean with a paired BCa bootstrap interval. Participant reduction is not introduced in Step 5. The current event, NRF, ROI, and overlay choices are labelled exemplar defaults, not universal framework requirements.

Steps 5.2 and 5.3 do not launch EEGLAB or a template-path initialiser. Their
active logical names resolve directly against this repository's `NRFs/`
directory; Step 5.3 also accepts an explicit template path and fails closed on
missing, malformed or conflicting template identity.

### Relation to the framework

This stage instantiates the **Post-core Guardrails** part of the framework. It is intended to help determine whether the screened dataset behaves plausibly before stronger claims are made.

## Points where user input or inspection is required

This workflow includes several manual decision points.

### Before running the workflow

- prepare `dataset_list.csv`
- ensure raw data are in the expected `data/raw/` structure
- confirm every script resolves this repository root without a fallback
- confirm EEGLAB and required toolboxes are available

### During Step 1

- review preprocessing options in `step_1_proc_4_preprocessing.m`

### During Step 2

- inspect event, channel, and epoch inventory outputs
- inspect `multievent_epochs`
- edit `epoch_type_summary.csv`
- optionally edit `nrf_config.ini`

### During Step 3

- choose which channels, event types, QC features, and NRF names to summarise

### During Step 4

- make manual epoch–channel screening decisions in the viewer

### During Step 5

- inspect excluded and included items
- review the configured Simple, NRF-shifted, or Woody average time-series view and the TF/PSD views
- review paired separation checks for QC and NRF metrics and their schema-v2 result files

## Key outputs produced by the workflow

Across the full workflow, the most important outputs are:

- processed epoched `.set` files
- QC-annotated and NRF-annotated `.set` files
- per-dataset summary CSVs and MAT files
- pooled QC, NRF, epoch, and manifest outputs
- immutable screening package and mutable screening decisions
- screened pooled outputs with `Exclude` flags
- excluded-item PNGs
- post-screening guardrail figures and console summaries
- per-script log files in `data/logs/`

## Logging and provenance

The workflow includes several provenance and audit features.

### Command Window logs

All runnable scripts write to ignored per-script log files in `data/logs/` via
`log_command_window.m`.

### Provenance in `.set` files

Some processing and quantification steps write structured provenance into `EEG.etc.simple.*`.

### Screening package hash

The screening package includes a SHA-256 hash tying it to the pooled inputs and QC feature list. This helps ensure that screening decisions are only applied to the correct data.

## Regression tests

`tests/run_all_tests.m` exercises preprocessing, response estimation, jitter
correction, all QC features, event helpers, NRF resolution and overlays,
configuration/cache behaviour, dependency failure modes and logging against a
frozen synthetic oracle. Numerical outputs use strict `isequaln` comparison.
Run it only in the accepted isolated MATLAB/EEGLAB test
environment.

From MATLAB, call the runner with explicit repository and EEGLAB roots:

```matlab
addpath(fullfile(frameworkRoot, 'tests'), '-begin');
results = run_all_tests(frameworkRoot, eeglabRoot);
assert(results.passed);
```

`tests/run_static_checks.sh` builds an isolated tracked snapshot and
checks repository shape, exact template and function inventories, the public
API surface, ignore policy, self-contained paths, caller contracts and coverage
manifest consistency without touching project data.

## Relationship to the methods paper

This repository is the practical MATLAB implementation of the associated methodological framework. The repository is intended to stand on its own as a workflow, while the associated paper provides the broader methodological rationale, framing, and evaluation.
