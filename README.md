# SIMPLE Framework

SIMPLE (Single-event Measurement Pipeline for EEG) is a MATLAB framework for
analysing individual EEG events. It keeps each event's waveform and
quality-control (QC) information linked to the researcher's screening decision
and the data retained for analysis. Each screened item is one event at one
recording channel.

**Software credits:** [Luke Baxter](https://github.com/lukebax), [Marianne van der Vaart](https://github.com/mvandervaart), and [Simon Marchant](https://github.com/simonmarchant) contributed equally to the development of this software.

**Associated methods paper:** citation and link to be added when available.

## Start here

This repository provides the shared workflow and a worked synthetic example.
It is intended for offline event-related EEG analysis, particularly when few
trials or channels are available. Neonatal noxious-evoked EEG is a central
application; other applications require their own scientific justification
and settings. The workflow includes manual inspection and screening. It is
not a general-purpose EEG toolbox, a real-time system, a clinical diagnostic
tool, or a conventional multichannel event-related-potential pipeline.

Choose the repository for your task:

| Repository | Purpose |
| --- | --- |
| **simple** (this repository) | Work through the synthetic example, understand the shared stages, or adapt the framework to another study. |
| [simple-synthetic-eeg-generator](https://github.com/simple-eeg/simple-synthetic-eeg-generator) | Create the synthetic EEG files used by the example. |
| [simple-oxford](https://github.com/simple-eeg/simple-oxford) | Use the Oxford workflow, including source preparation and downstream analyses. The methods paper uses the Petal trial. |
| [simple-strasbourg](https://github.com/simple-eeg/simple-strasbourg) | Use the NOCI-Prem workflow and its post-screening descriptive figure. |

Each MATLAB repository includes its own helper functions. The clinical
repositories use this README as a shared guide; they do not require a second
copy of `simple`. Clinical recordings are not included. To try the framework
without clinical data, follow the [synthetic tutorial](#synthetic-tutorial).

**Guide:** [Before you begin](#before-you-begin) ·
[Synthetic tutorial](#synthetic-tutorial) ·
[Workflow reference](#workflow-reference) ·
[Configuration reference](#configuration-reference) ·
[Technical reference](#technical-reference) · [Tests](#tests)

### Terms used in this guide

- An **epoch** is a segment of EEG around an event. An **epoch–channel item**
  is that segment at one recording channel; it is the unit screened here.
  Other trials or channels are not averaged into or substituted for that item.
- A **true-event epoch** contains the event of interest. An
  **internal-reference epoch** provides non-target EEG from the same recording
  and channel. The tutorial uses a period before the true event.
- **QC features** describe properties of the signal that a researcher can
  consider alongside its waveform during screening.
- A **neurodynamic response function (NRF)** is a predefined temporal response
  shape fitted to the EEG. Its fitted magnitude quantifies the response; it
  is not used to decide which items to exclude during screening.

## Before you begin

### Software

You need MATLAB, EEGLAB, and the toolboxes used by the selected steps:

- Statistics and Machine Learning Toolbox for operations such as `corr` and
  `robustfit`;
- Econometrics Toolbox for `fgls`;
- Signal Processing Toolbox for filtering and spectral checks; and
- Wavelet Toolbox for the time–frequency check.

The verified workflow environment is MATLAB R2026a Update 4 with EEGLAB
2026.0.0. The [regression tests](#tests) explicitly require those versions.
CleanLine is optional; preprocessing uses the configured notch-filter route
when CleanLine is not selected.

The core workflow has no macOS requirement. Its full MATLAB/EEGLAB regression
suite has been verified on macOS; Windows and Linux still need equivalent
end-to-end validation. The source-check workflow covers all three platforms.

### Get the code and open it in MATLAB

With Git installed, open a terminal in the folder where you want to keep the
repository and run:

```sh
git clone https://github.com/simple-eeg/simple.git
```

In MATLAB, open the new repository's `scripts/` folder as the Current Folder,
or add that folder to the MATLAB path. Make EEGLAB available on the MATLAB
path. Run scripts individually in their numbered order, starting with
`step_1_proc_1_get_event_types.m` after preparing the inputs below.

The 21 runnable scripts locate this repository from their saved position in
`scripts/`. You do not need to put a personal project path into them. They
stop if they cannot locate the repository or the required local helpers.

### Prepare the inputs

A fresh clone contains code, templates, configuration, tests, and empty
`data/` and `data_lists/` folders. For the worked example, create and copy the
inputs as described in the [synthetic tutorial](#synthetic-tutorial).

The workflow reads EEGLAB `.set` datasets listed in
`data_lists/dataset_list.csv`. The list identifies each recording and gives
its location relative to this repository. For example:

```text
subjectID,sessionID,runID,path_raw,EEGfile_raw
001,01,01,data/raw/sub-001/ses-01/eeg,sub-001_ses-01_run-01_eeg.set
```

Identifiers come from the `subjectID`, `sessionID`, and `runID` columns, rather
than being inferred from filenames. Keep raw files under `data/raw/` and use
forward slashes in the list's paths. The exact [path rules](#dataset-path-rules)
are documented below.

For another study, review event labels, channels, preprocessing and fitting
windows, NRF profiles, and output names before running anything. The supplied
settings describe the tutorial. Acquisition and study-specific source
preparation precede SIMPLE; participant contributions and group inference
must be defined for the downstream analysis, accounting for repeated
observations where applicable.

<a id="fixed-synthetic-demonstrator-route"></a>

## Synthetic tutorial

### Create and copy the data

Follow the [generator's setup and generation instructions](https://github.com/simple-eeg/simple-synthetic-eeg-generator#first-time-setup).
It creates a folder named `simple-synthetic-eeg-demo`. Copy its `raw/` folder
to `simple/data/raw/` and its `dataset_list.csv` to
`simple/data_lists/dataset_list.csv`.

The fixed example contains:

- 31 synthetic subjects, `001` through `031`, with session `01` and run `01`;
- one 30-second, 1,000-Hz recording per subject;
- one channel, with the exact label `Cz`;
- one `stimulus` event at 15 seconds (EEGLAB latency 15001);
- one self-contained `.set` file per recording, with no separate `.fdt` data
  file; and
- one row per recording in the dataset list, with `data/raw/...` paths
  relative to this repository.

Step 1.4 resamples the recordings to 500 Hz and adds the internal-reference
event `stimulus_prestim` 1,500 ms before `stimulus`.

### Map event types to NRF profiles

Step 2.2 creates `data/info/epoch_types/epoch_type_summary.csv`. Its NRF
columns are empty each time that step runs. Inspect the event, channel, and
epoch inventories, then enter the following profiles before Step 2.3. Leave
the preterm column empty.

| `Type` | `early_NRF` | `noxious_NRF` | `noxious_preterm_NRF` |
| --- | --- | --- | --- |
| `stimulus` | `term_foot_early` | `term_foot_nox` | |
| `stimulus_prestim` | `term_foot_early` | `term_foot_nox` | |

The two templates are bundled in `NRFs/`. They are used to analyse the
synthetic recordings, not to generate them. The fitted values demonstrate
template-based measurement; they do not validate biological or pain responses.

### Run one script at a time

Use the supplied settings for this fixed example. After each script, inspect
its log in `data/logs/` and the checkpoint below before proceeding. If a script
errors or is cancelled, investigate before continuing. Each run replaces that
script's previous log.

| Script | Stop and check |
| --- | --- |
| Step 1.1 event types | 31 inputs; only the declared raw event labels |
| Step 1.2 channels | 31 inputs; the sole channel is `Cz` |
| Step 1.3 processed paths | Every derived path remains under `data/processed` |
| Step 1.4 preprocessing | 31 self-contained processed sets; exactly two epoch types, with processing records |
| Step 2.1 QC | All nine configured QC values are present and finite for both items per subject |
| Step 2.2 epochs | Exactly `stimulus` and `stimulus_prestim`; no unexpected multi-event epoch |
| Step 2.3 NRF | Complete the mapping table above first, then verify 124 stored fits |
| Step 3.1 summary paths | Every path remains under `data/summary` |
| Step 3.2 individual summaries | 31 complete four-file summary groups |
| Step 3.3 pooled summaries | 62 QC rows, 124 NRF rows, 31 manifest rows, and 31 epoch structures |
| Step 3.4 pooled plots | Inspect all 31 true `stimulus` items; figures are displayed without saving |
| Step 4.1 package | One fixed 62-item schema-v2 screening package; do not rerun this step |
| Step 4.2 viewer | Review the items, mark exclusions, then click **Finish** |
| Step 4.3 apply decisions | Decisions match the package and are applied to all corresponding outputs; expected 61 retained items |
| Step 5.1 excluded figures | One complete batch of excluded-item images |
| Step 5.2 included epochs | Inspect every retained true-event item and configured overlay |
| Step 5.3 average time series | Inspect the simple-mean trace and early/noxious NRF overlays |
| Step 5.4 average time–frequency | Inspect the fixed 3–30-Hz view using the mean baseline |
| Step 5.5 average power spectral density (PSD) | Inspect the fixed post-stimulus multitaper view |
| Step 5.6 QC comparison | 30 complete `stimulus - stimulus_prestim` pairs and a schema-v2 result file |
| Step 5.7 NRF comparison | The same 30 pairs for noxious `fglsCoef` and a schema-v2 result file |

Before screening there are 62 epoch–channel items and 124 NRF rows. Subject
31's true `stimulus` item contains the declared artefact and is the expected
sole exclusion. Screening remains manual: no script makes that decision.
If the displayed evidence or counts differ from those expected, stop and
investigate. Do not alter data or exclusions merely to make the counts match.

## Workflow reference

The table maps this repository's five software stages to the clinical
repositories. Each clinical README explains its additional source-preparation
and downstream analysis stages.

| Stage in `simple` | Purpose | Oxford / Strasbourg stage |
| --- | --- | --- |
| 1: `proc` | Inspect and preprocess data; construct paired epochs | 3 |
| 2: `quant` | Calculate QC features and response estimates | 4 |
| 3: `sum` | Assemble per-dataset and pooled summaries | 5 |
| 4: `screen` | Record and apply human screening decisions | 6 |
| 5: `check` | Describe retained outputs after screening | 7 |

The paper describes five scientific steps: preprocessing and paired-epoch
construction, QC description, response quantification, human screening, and
post-screening descriptive checks. The software combines QC and response
quantification in Step 2 and gives summary preparation its own Step 3.

### Step 1: preprocessing

Run these scripts in order:

1. `step_1_proc_1_get_event_types.m`
2. `step_1_proc_2_get_channels.m`
3. `step_1_proc_3_add_processeds.m`
4. `step_1_proc_4_preprocessing.m`

This stage reads the dataset list, inventories event and channel labels,
derives output paths, and preprocesses continuous data. It deletes unwanted
events and adds offset events where configured, then creates true-event and
internal-reference epochs. Processing records are stored in the `.set` files.

Outputs are the updated dataset list, event and channel summaries in
`data/info/event_types/` and `data/info/channels/`, and processed `.set` files
under `data/processed/`.

Before adapting Step 1.4 to another study, review its rereferencing,
resampling, band-pass and line-noise filtering, event deletion, offset events,
epoch windows, and baseline correction.

### Step 2: quantification

1. `step_2_quant_1_QC_feature_extraction.m`
2. `step_2_quant_2_get_epochs.m`
3. `step_2_quant_3_NRF_feature_extraction.m`

This stage calculates QC features for selected channels, inventories epoch
types, reports epochs containing multiple event labels, and fits the selected
NRFs. QC and response annotations are stored in the processed `.set` files
before screening. `NRFUtils.m` supports profile mapping and fitting.

**Before Step 2.3**, inspect `data/info/epoch_types/multievent_epochs/` for
unexpected labels or overlap between true-event and internal-reference
epochs. Then enter the required profiles in
`data/info/epoch_types/epoch_type_summary.csv`. Use the
[mapping above](#map-event-types-to-nrf-profiles) for the tutorial.

### Step 3: summarisation and pooling

1. `step_3_sum_1_add_summaries.m`
2. `step_3_sum_2_summarise_individual.m`
3. `step_3_sum_3_summarise_pooled.m`
4. `step_3_sum_4_plot_epochs.m`

This stage exports the selected channels, event types, QC features, and NRF
results, then combines them across datasets. It prepares waveform and QC
evidence for screening and keeps response estimates linked for later use.
Review these selections in the scripts when adapting the workflow.

Each dataset produces four files: `<stem>_qc_features.csv`,
`<stem>_nrf_features.csv`, `<stem>_epochs_index.csv`, and `<stem>_epochs.mat`.
The pooled outputs are `pooled_eeg_qc_features.csv`,
`pooled_eeg_nrf_features.csv`, `pooled_eeg_epochs.mat`, and the dataset-level
`pooled_eeg_manifest.csv`.

Step 3.4 displays pooled epochs with optional NRF overlays. Step 3.2 skips
datasets with multi-event epoch labels, which is why the Step 2 inventory
needs inspection before proceeding.

### Step 4: human screening

1. `step_4_screen_1_init_package.m` creates the screening package.
2. `step_4_screen_2_viewer_rate_epochs.m` opens the mouse-driven viewer.
3. `step_4_screen_3_apply_decisions.m` applies the saved decisions.

Review each item using its waveform and QC evidence. Keep NRF magnitudes and
downstream group or outcome information out of screening decisions. True-event
and internal-reference items receive separate statuses.

The package fixes the pooled waveforms and QC values used for review. It is
immutable once created; decisions are saved separately and can be updated in
the viewer. A package hash checks that decisions are applied to the correct
data. Decision saves are atomic, so an interrupted save cannot leave a
partially replaced decision file.

The outputs in `data/summary/screening/` are:

- `screening_package.mat`;
- `screening_decisions.mat`;
- `pooled_screened_eeg_epochs.mat`;
- `pooled_screened_eeg_qc_features.csv`; and
- `pooled_screened_eeg_nrf_features.csv`.

Screened outputs carry `Exclude` flags. In the viewer, `File > Save PDF...`
saves the current display, including all plots and the Navigator. Exporting
that snapshot does not change decisions.

### Step 5: post-screening descriptive checks

1. `step_5_check_1_save_excluded_figs.m`
2. `step_5_check_2_plot_included_epochs.m`
3. `step_5_check_3_plot_average_ts.m`
4. `step_5_check_4_plot_average_tf.m`
5. `step_5_check_5_plot_average_psd.m`
6. `step_5_check_6_sep_check_qc.m`
7. `step_5_check_7_sep_check_nrf.m`

Inspect excluded and retained items, average time series, time–frequency
representations, power spectral densities, and paired QC and NRF comparisons.
These descriptive checks do not change screening decisions.

Step 5.1 writes a verified batch of excluded-item PNGs to
`data/summary/screening/excluded_epochs/`, with rollback protection when
replacing an existing batch. Steps 5.2–5.5 display figures and create workspace
objects and logs; they do not save those figures automatically. Review the
selected simple, NRF-shifted, or Woody averaging method and the time–frequency
and PSD settings when adapting the workflow.

Steps 5.6 and 5.7 form each complete `true - internal reference` difference
within a recording and channel, then estimate its paired mean or median with
a bias-corrected and accelerated (BCa) bootstrap interval. They do not combine
recordings into participant-level observations. The event, NRF, region of
interest (ROI), and overlay choices are example settings for this application.

They save the paired results atomically using schema
`simple-paired-separation-result-v2`:

- `data/summary/screening/step_5_check_6_sep_check_qc_result.mat`;
- `data/summary/screening/step_5_check_7_sep_check_nrf_result.mat`.

## Configuration reference

### Dataset list

`data_lists/dataset_list.csv` is the central dataset list, also called the
registry in the code. It is both an input and a file updated by the workflow.
In addition to the identifiers and input paths, it gains columns such as
`event_types`, `channels`, `path_processed`, `EEGfile_processed`, `epoch_types`,
and `path_summary`.

### NRF profiles and event mapping

[`NRFs/nrf_config.ini`](NRFs/nrf_config.ini) defines named fitting profiles.
Each specifies a template name, baseline length, maximum timing shift
(`jitter`), channel labels, and one fitting-window start. Set either
`projectionTimes_pre` or `projectionTimes_post`, leaving the other empty.
The file's comments explain the units and required epoch coverage.

`data/info/epoch_types/epoch_type_summary.csv` maps each discovered event type
to profiles in that INI file. Its mapping columns are `early_NRF`,
`noxious_NRF`, and `noxious_preterm_NRF`. A cell contains one profile name;
leave it empty if that NRF family should not be fitted to the event type.
For the fixed tutorial, use the supplied mapping and settings unchanged.

### Bundled templates

`NRFs/` contains `early_NRF_500Hz.mat`, `noxious_NRF_500Hz.mat`, and
`noxious_preterm_NRF_500Hz.mat`. Each stores a real double column vector `NRF`
and scalar `fs = 500`. Each template has mean zero and discrete L2 norm one
within floating-point precision. The template is dimensionless, so its signed
fitted coefficient has the EEG input's unit. That coefficient is not a peak
EEG amplitude.

The template and EEG sampling rates must match; the estimator does not
resample templates. Template basenames resolve directly against this
repository's `NRFs/` folder, rather than through the MATLAB search path.
Explicit canonical MAT-file paths are supported where documented. Missing,
malformed, or conflicting template identities stop the relevant operation.

The tutorial fits two term-foot profiles at `Cz`. Before timing alignment,
the early fit covers 100–350 ms (126 samples), and the later fit covers
400–700 ms (151 samples), including both endpoints. Both use a 200 ms
pre-event baseline and allow a shift of up to 100 ms in either direction.

## Technical reference

### Repository folders

| Folder | Contents |
| --- | --- |
| `scripts/` | Numbered workflow scripts and `log_command_window.m` |
| `functions/` | The helper functions used by those scripts |
| `NRFs/` | Tracked templates and NRF configuration |
| `data_lists/` | Local dataset lists and study spreadsheets |
| `data/info/` | Event, channel, epoch, and multi-event inventories to inspect |
| `data/summary/` | Per-dataset, pooled, screened, and descriptive outputs |
| `data/logs/` | Per-script Command Window logs |
| `tests/` | Synthetic test fixtures, a MATLAB test runner, and static checks |
| `.github/workflows/` | Automated source checks on macOS, Windows, and Linux |

The tracked `.gitkeep` files preserve the empty `data/` and `data_lists/` folders
in a clone. Generated data, logs, screening decisions, analysis outputs, and
CSV/XLSX project lists remain local and are excluded from version control.

### Dataset path rules

Raw directories must be `data/raw` or descendants of it. Processed and
summary directories must likewise remain under the exact `data/processed`
and `data/summary` roots. Paths must be non-empty, relative to the project,
and written with forward slashes. EEG filenames must be basenames with the exact
lowercase `.set` extension. Processed targets and all four per-dataset
summary targets must be unique.

The validator rejects absolute paths, traversal components such as `..`,
repeated separators, backslashes, filenames containing a path, and symbolic
links that resolve outside the permitted roots.

Every registry path is validated before a governed write to processed datasets
or per-dataset summaries. This means the complete dataset list is checked
before any stage derives or writes those targets. An invalid required path
stops that stage before it changes the list, processed datasets, or summary
outputs.

### Function interfaces

The main interfaces are `preproc(EEG, options)` for preprocessing,
`quality_control_features` and its 11 `calc_*` functions for QC,
`estimate_response(EEG, options)` for response estimation, `jittercorrect`
for timing alignment, and `add_offset_events` for offset events. Other
helpers support event handling, averaging, post-screening checks, and dataset
path validation. The function help blocks describe their arguments and units.

Steps 5.2 and 5.3 do not start EEGLAB or initialise a template search path.
They resolve template names directly in `NRFs/`; Step 5.3 also accepts an
explicit template path and checks the exact file supplied.

### Logs and provenance

`log_command_window.m` starts and stops each script's Command Window log in
`data/logs/`. A new run replaces that script's previous log. Some processing
and quantification steps also store structured records in
`EEG.etc.simple.*` inside the `.set` files.

The screening package contains a SHA-256 hash linking it to the pooled inputs
and QC feature list. This verifies the association between data and decisions;
it is not a history of every decision made in the viewer.

## Tests

The tests use synthetic fixtures and do not require or inspect clinical EEG
data. Run the MATLAB suite in a separate session with MATLAB R2026a Update 4,
EEGLAB 2026.0.0, and EEGLAB's `option_storedisk` and `option_parallel` options
disabled. These version and option checks are enforced by the test runner.

Replace the example paths with your installation locations:

```matlab
simpleRoot = '/path/to/simple';
eeglabRoot = '/path/to/eeglab';
addpath(fullfile(simpleRoot, 'tests'), '-begin');
results = run_all_tests(simpleRoot, eeglabRoot);
assert(results.passed);
```

`tests/run_all_tests.m` checks preprocessing, response estimation, timing
alignment, all QC features, event helpers, template resolution and overlays,
configuration and caching, dataset paths, processing records, removal of stale
NRF results, dependency failures, and logging. It compares numerical outputs
with saved expected results using strict `isequaln` equality.

Filesystem-link tests use Java's native file API. If the filesystem does not
support links, or a Windows account lacks symbolic-link privileges, those
cases are reported as skipped rather than counted as passes. The result's
registry count includes only cases that ran successfully.

The processing safety source checks run on macOS, Windows, and Linux with
Python 3, without MATLAB or clinical data. From the repository root:

```sh
python tests/check_processing_safety_contracts.py .
```

The complete static repository audit additionally requires Bash, Git, Python 3,
and Unix command-line tools, including `shasum`. From the repository root:

```sh
./tests/run_static_checks.sh
```

This creates an isolated snapshot of tracked files and checks the repository
layout, template and function inventories, public interfaces, ignore rules,
local paths, caller requirements, and coverage manifest. It does not touch
project data.

The associated methods paper provides the scientific rationale and evaluation;
this guide documents how to use the software.
