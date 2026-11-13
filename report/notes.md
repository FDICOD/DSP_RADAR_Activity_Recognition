# Project notes

## Environment (task 1.2)
Checked in MATLAB Online (2026-11-01): MATLAB R2026b (26.2, Update 1), GLNXA64.
Signal Processing Toolbox: present. Statistics and Machine Learning Toolbox: present.
Deep Learning Toolbox: present. Many other toolboxes are present through the college licence.
Still to do: the other team members run `check_environment` and add their result here.

## Dataset check (tasks 1.3 and 1.4)
Source: University of Glasgow, "Radar signatures of human activities", DOI 10.5525/gla.researchdata.848 (CC BY 4.0).
Downloaded `Dataset_848.7z` (2,060,197,481 bytes) and extracted it to about 15 GB of text.

### Files per session (counts match the data sheet exactly: 1,754 `.dat` files)
| Session folder | Files | People (session+ID) | Walk | Sit | Stand | A04 | A05 | Fall |
|---|---|---|---|---|---|---|---|---|
| 1 December 2017 | 360 | 20 | 60 | 60 | 60 | 60 | 60 | 60 |
| 2 March 2017 | 48 | 4 | 8 | 9 | 7 | 8 | 8 | 8 |
| 3 June 2017 | 162 (161 usable) | 9 | 27 | 26 | 28 | 26 | 27 | 27 |
| 4 July 2018 | 288 (287 usable) | 16 | 48 | 48 | 48 | 47 | 48 | 48 |
| 5 February 2019 UoG | 306 | 17 | 51 | 51 | 51 | 51 | 51 | 51 |
| 6 February 2019 NG Homes | 301 | 20 | 58 | 60 | 60 | 60 | 60 | 3 |
| 7 March 2019 West Cumbria | 289 | 20 | 60 | 58 | 57 | 57 | 57 | 0 |
| **Total usable** | 1,752 | 106 | 312 | 312 | 311 | 309 | 311 | 197 |

(Counts are by the activity code after the letter A. A04/A05 are the two codes whose names disagree between sources; see below.)

### File format (confirmed on real files)
- Four header lines: carrier 5.8e9 Hz, chirp 1.0 ms, 128 samples per chirp, bandwidth 4e8 Hz. Identical in all files.
- Then one sample per line as `1812+1897i` (integer I, sign, integer Q, `i`), CRLF line endings.
- Values are integers from 1,141 to 35,556, so they do not fit signed 16-bit; unsigned 16-bit is used for the compact copy.
- Length: 1,439 files of 5 s (5,000 chirps), 305 of 10 s (10,000 chirps), 8 of 20 s (20,000 chirps, NG Homes).

### Differences from the design assumptions and how they are handled
1. Text size is about 15 GB, too large to upload. A one-off script, `tools/convert_dat_to_mat.py`, makes a compact `.mat` copy (3.1 GB, uint16 I and Q plus the header). Two sample files were checked to be identical to their text sources.
2. Repetition is one digit in most sessions and two digits in December 2017 and February 2019 UoG. One file (`1P53A1R01`) has a one-digit activity field.
3. Three files have a leading digit that differs from the activity code (`3P03A02R1`, `2P34A03R1`, `6P01A05R03`). They are excluded as ambiguous.
4. Two hand-made copies (`4P30A04R3 (2).dat`, `4P64A04R3 - Copy.dat`) are byte-identical to their originals and are skipped.
5. The data sheet says code 4 is picking up an object and code 5 is drinking; the authors' `Label_extract4.m` comment says 4 is drinking and 5 is picking. The mapping is a setting and will be checked against the data (task 6.4).
6. The data sheet says West Cumbria has a fall activity, but it has none. Falls come from the first five sessions plus three in NG Homes, so falls are the rarest class.
7. P08 is the same person (age 33, 170 cm) in the February 2019 UoG and NG Homes sessions. They are merged when splitting. Other reused IDs are different people (for example P03 is 23 and 180 cm in March 2017 but 32 and 183 cm in February 2019).
8. The original data sheet is `Document for all datasets - 03092019.pdf` inside the archive.

### Where the data lives (outside the repository)
`~/project-dsp-data/`: `Dataset_848.7z`, `extracted/` (text), `converted/` (compact), `upload/` (one zip per session, `manifest.csv`, and `samples/` for loader tests).

## Real-data summary from `build_dataset_index` (task 2.5)
Run in MATLAB Online on the converted data (seed 1):

- Files found 1,752 (the 2 hand-made copies were never converted); included 1,749; excluded 3 (`3P03A02R1`, `2P34A03R1`, `6P01A05R03`, all inconsistent digits).
- 105 people after merging P08. Split: train 63, val 21, test 21 people.
- Recordings per activity (train / val / test / total): walking 188/62/62/312; sitting down 186/63/62/311; standing up 187/61/62/310; picking up 186/61/62/309; drinking 186/62/62/310; falling 118/41/38/197.
- Lengths: 5 s (1,436 files), 10 s (305), 20 s (8). Carrier 5.8 GHz, chirp 1 ms, 128 samples per chirp in every file.
- **Bandwidth is not the same in every file.** 1,689 files have 400 MHz as the data sheet says, but 60 files have **100 MHz** in their header. All 60 are in the West Cumbria session (subjects P51-P55; walking, sitting, standing, picking up and drinking, 12 each). Range resolution in those files is c/(2B) = 1.5 m per bin instead of 0.375 m.
  Check: the strongest moving return in those files is at range bin 3 (3 x 1.5 m = 4.5 m), and in the 400 MHz files of the same session at bin 12 (12 x 0.375 m = 4.5 m). The physical range agrees, so the header is believable and the range axis (computed from each file's own bandwidth) is correct.
  Consequence: the fixed 3.7-11.3 m interval covers about 21 bins in a 400 MHz file but only 5 bins in a 100 MHz file, so fewer range bins are combined in the Doppler stage. This is a possible source of a session effect and should be mentioned when results for the West Cumbria session are discussed.

## Range-time maps (task 3.4)
`show_range_time` (February 2019 laboratory session, subject P01, repetition 1) shows, with static returns removed by mean subtraction:
walking is continuous over the 10 s recording with the person between about 3 and 9 m; sitting down and standing up each show one burst of about 2 s (roughly 1.5-3.7 s and 1.5-3.2 s); picking up an object and drinking show motion at the start and the end; the fall is a strong, broad burst between about 2 and 3 s that reaches out to about 12 m. The person is clearly visible and the activities differ. The strongest returns sit near 3-7 m, inside the default 3.7-11.3 m interval, but the fall reaches the edge of it, which is one reason to compare fixed and automatic range-bin selection in Experiment B.

## Pipeline figures on real data (tasks 4.4, 5.4, 6.1-6.3)
Run in MATLAB Online (113 of 113 tests passing, including our STFT versus MATLAB's `spectrogram` on two real recordings).
Subject P01, February 2019 laboratory session.

- **Class gallery** (`class_gallery.png`): the six activities have clearly different signatures on one colour scale.
  Walking: periodic leg oscillations reaching about +/-3-4 m/s around a torso speed of about +1 m/s, which turns negative after about 4 s (the person turns round). Sitting down and standing up: single bursts of about 2 s with opposite sign. Picking up an object: two lobes within 3 s, reaching about +/-1.5 m/s. Drinking: only small motion (about +/-0.7 m/s) at the start and end. Falling: one sharp negative burst reaching about -5 m/s near 3 s.
  Picking up has a visibly larger velocity extent than drinking for this person, which agrees with the data sheet's naming of codes 4 and 5 (task 6.4 tests this on many people).
- **Clutter removal** (`preprocessing_by_activity.png`, `demo_*_2/3/4.png`): before, the range-time maps are dominated by static returns and the Doppler spectrum has a single 0 dB spike at 0 m/s, 15-20 dB above the person's spectrum; after the high-pass the person's motion is clean, the spike is gone and the rest of the spectrum is unchanged (the two curves overlap exactly). The spectrogram's bright 0 m/s band disappears and the motion is untouched.
- **Side effect**: the high-pass leaves a narrow notch at 0 m/s (about +/-0.1 m/s, because 3.75 Hz is 0.1 m/s at 5.8 GHz). Very slow body motion is removed with the clutter.
- **Observation to check later**: faint horizontal lines at about +/-2.6 m/s (+/-100 Hz) are visible in the walking spectrogram before and after processing. They are symmetric, so they look like a real-valued interference line, possibly twice the 50 Hz mains frequency. They are weak (about 30 dB below the person) and not removed by the pipeline.
- The demo's summary figure reports the settings used and that the prediction stage is not available yet.

## Activity codes 4 and 5 (task 6.4)
The data sheet says code 4 = picking up an object and code 5 = drinking; the authors' example script says the opposite.
`check_activity_mapping` compared the velocity extent of the two codes for 200 people who did both in the same repetition
(full front end, default settings, seed 1): median 95%-power speed 0.49 m/s for code 4 against 0.32 m/s for code 5 (code 4
wider in 84% of pairs, sign-test p = 9e-23); median rms velocity 0.29 against 0.24 m/s (70% of pairs, p = 2e-8).
Picking something up moves the whole torso and should be faster than raising a cup, so this supports the data sheet.
The default mapping in `dsp.defaultSettings` stays as the data sheet has it. This is physical evidence, not ground truth,
and the report should say so. Per-pair numbers are in `results/mapping_check/pairs.csv`.

## Experiment C: STFT window and overlap (task 7.4, part 1)
24 validation recordings (4 per activity), seed 1, default preprocessing, default 4x zero padding. Robustness is the correlation
of the noisy spectrogram with the clean spectrogram of the same STFT setting (input SNR of 10 dB and 0 dB).

| Window | Doppler resolution | Velocity resolution | Corr. at 10 dB (overlap 50 / 75 / 95%) | Corr. at 0 dB (overlap 50 / 75 / 95%) |
|---|---|---|---|---|
| 0.1 s | 10 Hz | 0.26 m/s | 0.887 / 0.889 / 0.890 | 0.686 / 0.688 / 0.688 |
| 0.2 s | 5 Hz | 0.13 m/s | 0.884 / 0.885 / 0.885 | 0.664 / 0.664 / 0.665 |
| 0.4 s | 2.5 Hz | 0.065 m/s | 0.874 / 0.878 / 0.879 | 0.624 / 0.629 / 0.631 |
| 0.8 s | 1.25 Hz | 0.032 m/s | 0.864 / 0.866 / 0.867 | 0.607 / 0.609 / 0.612 |

Run time of the STFT per recording: about 0.009 s at 50% overlap, 0.017 s at 75%, 0.08-0.09 s at 95%.

What the numbers show:
- Resolution follows theory exactly (velocity resolution = (1/window) x lambda/2). Longer windows resolve speed more finely but
  smear changes in time; the time step is set by the overlap (0.05 s for a 0.1 s window at 50%, 0.04 s for a 0.8 s window at 95%).
- Shorter windows are somewhat more robust to noise by this measure: the correlation falls by about 0.02 at 10 dB and 0.08 at 0 dB
  going from 0.1 s to 0.8 s. A possible reason is that a coarse spectrogram has less fine structure for noise to disturb; this
  measure does not say how much useful detail a short window throws away.
- Overlap barely changes robustness (at most 0.006 between 50% and 95%) but 95% costs about 9 times more computation than 50%
  and 5 times more than 75%. Beyond 75% there is no measurable gain for this measure.
- Run time is not a constraint at any setting (under 0.1 s per recording).

Provisional choice for the later studies: 0.2 s window with 75% overlap (5 Hz / 0.13 m/s resolution, 0.05 s time step), which
keeps enough velocity resolution to see limb motion and almost all of the robustness. This is not final: the window has to be
confirmed with classifier results on the validation split (task 9.5). Limits: 24 recordings, one noise seed, no significance test,
and differences between neighbouring settings are small (0.002-0.02).

## Experiment B: clutter removal and range-bin selection (task 7.4, part 2; first run)
24 validation recordings (4 per activity, seed 1). Reference configuration: high-pass + fixed bins. "Fidelity" is the
correlation with the reference's clean spectrogram; noise is added to the raw samples, identical for all configurations.

| Configuration | Motion share of energy (beyond +/-0.15 m/s) | Range bins used | Fidelity clean / 20 / 10 / 5 / 0 dB |
|---|---|---|---|
| none + fixed | 0.25 | 21 | 0.80 / 0.80 / 0.77 / 0.73 / 0.69 |
| high-pass + fixed (reference) | 0.77 | 21 | 1.00 / 0.98 / 0.89 / 0.79 / 0.66 |
| none + auto | 0.28 | 13.8 | 0.80 / 0.80 / 0.78 / 0.74 / 0.68 |
| high-pass + auto | 0.77 | 13.8 | 0.99 / 0.98 / 0.90 / 0.79 / 0.65 |

- **Clutter removal is the choice that matters.** Without it only a quarter of the spectrogram's energy is motion; with it, over
  three quarters. Without clutter removal the spectrogram differs visibly from the reference even with no noise (correlation 0.80).
- **Fixed versus automatic range bins hardly matters.** With clutter removal the two give practically the same spectrogram (clean
  correlation 0.995, normalised error 0.008) and the same motion share. Automatic selection uses about 14 bins instead of 21.
  The fixed interval of 3.7-11.3 m therefore contains the person in these recordings. The mean of exactly 21 bins for the fixed
  interval means this sample contains no 100 MHz file, so the coarser bins of those files are not tested here.
- **Noise.** The reference's fidelity falls from 1.00 to 0.66 between clean and 0 dB; the configurations without clutter removal
  start lower and fall less, so the 'fidelity' column is not a fair robustness measure (it favours the reference at high SNR by
  construction). The second run adds 'selfFidelity', each method against its own clean spectrogram. The large standard
  deviation at 0 dB (0.25-0.28) shows some activities are much more affected than others.
- Denoising (the optional slow-time low-pass) is not part of this comparison; it can be added to the later classifier-based study.

### Experiment B, second run: each method against its own clean spectrogram
| Configuration | Self-correlation at 20 / 10 / 5 / 0 dB input SNR |
|---|---|
| none + fixed | 1.000 / 0.981 / 0.954 / 0.920 |
| high-pass + fixed | 0.976 / 0.885 / 0.791 / 0.665 |
| none + auto | 1.000 / 0.988 / 0.966 / 0.929 |
| high-pass + auto | 0.981 / 0.905 / 0.804 / 0.662 |

By this measure the spectrograms WITHOUT clutter removal are the more robust ones (0.92 against 0.66 at 0 dB). That does not mean
they are better. Without clutter removal the picture is dominated by the very strong static band at 0 m/s, which noise hardly
changes, so the whole image stays similar; after clutter removal only the weak moving components remain, and noise buries them.
The measure scores similarity of the whole picture, not how much of the person's motion survives, so it cannot decide between the
configurations. The first run's motion share (25% against 77% of the energy) shows what the extra similarity is made of.
Conclusion: clutter removal stays in the default pipeline (it clearly exposes the motion), range-bin selection mode does not
matter, and which setting recognises activities better under noise is decided by classifier accuracy on the validation split
(Experiments D and E, task 9.5). The large standard deviation of the high-pass self-correlation at 0 dB (0.25-0.28) shows that
weak-motion activities are affected much more than strong ones.

## Instructor (task 1.5)
Confirmed (2026-11-02): the course instructor allows the Glasgow dataset instead of Rad-HAR.

## MATLAB Drive read problems
Several times a file on MATLAB Drive could not be read although its size was correct (for example `5 February 2019 UoG
Dataset/1P01A01R01.mat`: 3,694,959 bytes as expected, but `fread` returned nothing), and the same file had been read fine
shortly before. `check_data_sizes` found all 1,752 files at the right size. The cause is probably Drive's on-demand file access.
Mitigations: `dsp.readConverted` retries with 1, 2 and 4 s pauses and reports size and first bytes; `stage_data` copies the data
to the session's local disk once per MATLAB Online session and verifies every size (all scripts then read the local copy);
real-data tests report an unreadable file as incomplete rather than failed.

## Status at 2026-11-02 and next steps
- Done and verified in MATLAB Online (165 of 165 tests in the last complete run): data handling, range processing, clutter removal,
  our own STFT (agrees with MATLAB's `spectrogram`), the stage-by-stage demo, noise injection, Experiments B and C, the
  activity-code check. The instructor allowed the Glasgow dataset.
- Written but NOT yet run in MATLAB: the classifier code (`trainClassifier`, `tuneClassifier`, `predictClassifier`, metrics,
  `saveModel`, `featureTable`, `run_classification`, `experiment_A`, `experiment_D`) and their tests (TestMetrics, TestClassifiers,
  TestFeatureTable, TestStageData, expected 206 tests in total). Feature extraction has only been tested on synthetic spectrograms.
  No classification results exist yet; none may be reported until `experiment_A` has been run.
- Final report: `DSP_Project_Submission_Template.docx` has been analysed (cover page, tables of
  contents/figures/tables, abstract, sections 1-5, references, team details table, checklist). Still needed from the team before the
  report can be completed: each member's registration number, email, phone, role and photo (the template asks for all of them).
  Figures available in Downloads: range_time_by_activity.png, class_gallery.png, preprocessing_by_activity.png,
  demo_1P01A01R01_1..6.png. The Experiment B and C charts were not downloaded; their numbers are in this file.
- Tooling found for building the report: Word (Mac) can export a docx to PDF if the file is inside
  ~/Library/Containers/com.microsoft.Word/Data/Documents; matplotlib and python-docx are in a throw-away venv. The template's zip
  has a bad checksum on its logo image and must be repacked before python-docx can open it.
