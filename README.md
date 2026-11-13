# DSP-based human activity recognition from radar micro-Doppler

Course project (DSP). A MATLAB pipeline that turns raw FMCW radar recordings into
range-time maps, Doppler spectra and micro-Doppler spectrograms, then recognises the
activity. The signal-processing stages are the main deliverable; classification is a
thin layer on top.

Data: University of Glasgow, "Radar signatures of human activities"
(DOI 10.5525/gla.researchdata.848, CC BY 4.0). Please cite the dataset authors' related
publication in any report.

## What the dataset is
- 5.8 GHz FMCW radar, 400 MHz bandwidth, 1 ms chirps, 128 samples per chirp.
- 1,754 text files in seven session folders (about 15 GB as text); 106 people (a person is
  session + subject ID; IDs are reused between sessions).
- File names: `1P05A01R1.dat` = leading digit, `P` + subject, `A` + activity code, `R` + repetition.
- Activity codes (data sheet order, checked against the data in task 6.4):
  1 walking, 2 sitting down, 3 standing up, 4 picking up an object, 5 drinking, 6 falling.
- Details and differences found on the real files: `report/notes.md`.

## Requirements
MATLAB with Signal Processing Toolbox and Statistics and Machine Learning Toolbox
(Deep Learning Toolbox only for the optional CNN). MATLAB Online works; see
`report/matlab_online_workflow.md`.

## Setup
1. Put the project folder in MATLAB's current folder, then run `startup`.
2. `check_environment` lists the MATLAB release and toolboxes.
3. `run_all_tests` runs the test suite and writes `results/test_log.txt`.

## Data
The raw text is too big to upload, so a compact copy is used (unsigned 16-bit I/Q plus the
header, one `.mat` per recording, 3.1 GB in total). It is made once by
`tools/convert_dat_to_mat.py` (Python with numpy and scipy) from the extracted archive:

    python tools/convert_dat_to_mat.py <extracted_dir> <output_dir>

Folder layout expected by the code (not tracked by Git):

    data/converted/<session folder>/<recording>.mat
    data/samples/dat/*.dat       small sample recordings in text form (loader tests)
    data/samples/mat/*.mat       the same recordings, converted (loader tests)

To unpack uploaded zips: place the `*_Dataset.zip` files in `data/` and run `unpack_data`.
Then run `build_dataset_index` to catalogue the recordings, make the person-wise split and
write `results/dataset/summary.txt`.

The loader reads both the original text (`dsp.readDat`) and the converted files
(`dsp.readConverted`); a test checks they give identical samples.

## Running the pipeline and experiments (MATLAB Online)
Every new session: `cd('/MATLAB Drive/project-dsp'); startup; stage_data` (copies the data to local disk, a few minutes).
Then, for example:

    run_all_tests                               % unit tests
    demo_pipeline(Save=true, Show=false)        % stage-by-stage demo, PNGs in results/figures
    experiment_B; experiment_C                  % signal-level studies
    experiment_A                                % baseline SVM (validation split only)
    experiment_D                                % SVM, k-NN and random forest compared
    experiment_A('UseTest', true)               % final run that also scores the test split once

Feature extraction is cached (`results/cache`), so an interrupted run resumes where it stopped.

## Folders
| Folder | Contents |
|---|---|
| `src/+dsp/` | Pipeline functions (`dsp.` prefix) |
| `scripts/` | Entry points: environment check, tests, dataset index, unpack, later the demo and experiments |
| `tests/` | `matlab.unittest` tests |
| `tools/` | One-off data preparation (Python) |
| `report/` | Notes and workflow documents |
| `results/` | Generated output (not tracked) |
