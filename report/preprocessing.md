# Preprocessing choices

Everything below is a setting in `dsp.defaultSettings`; none of it is fixed in the code. Each step can be
switched off, and Experiment B compares the alternatives.

## Order
1. Range processing: reshape into chirps, window, range FFT, keep the non-negative beat frequencies.
2. Range-bin selection (on the unprocessed range-time data).
3. Clutter removal along slow time, in every range bin.
4. Optional denoising along slow time.
5. Optional amplitude normalisation.
6. Doppler FFT / STFT over the selected bins; magnitudes are added across bins (non-coherent combination).

## Range processing
- Window: rectangular (`range.window = 'rect'`), as in the dataset authors' example. Hann and Hamming are available; a
  taper lowers range sidelobes but widens the main lobe.
- Zero padding: none (`range.padFactor = 1`). Padding only interpolates; it does not improve resolution.
- Resolution: c / (2 B) = 0.375 m for 400 MHz, 1.5 m for the 60 files with 100 MHz. The bandwidth is read from each file.
- Range bins for the Doppler stage: fixed interval 3.7 to 11.3 m (21 bins at 400 MHz, the authors' bins 10 to 30), or
  automatic selection of the bins around the strongest moving return.

## Clutter removal (`clutter.method = 'highpass'`)
Static reflectors (walls, furniture, the radar's own leakage) give a constant value in a range bin, a spike at 0 Hz Doppler
that is far stronger than the person. The default is mean subtraction followed by a 4th-order Butterworth high-pass at
3.75 Hz (the authors' MTI filter: cut-off 0.0075 of the Nyquist rate at 1 kHz).
- Why mean subtraction first: it removes the DC level exactly, so the filter starts without a large step.
- Why 3.75 Hz: low enough to keep slow body motion (about 0.1 m/s at 5.8 GHz) and high enough to remove drift.
- Alternatives: `mean` only, and a two-pulse canceller, whose gain 2 sin(pi f / PRF) is not flat and so distorts the spectrum.
- Cost: the filter starts from rest, so the first few tens of chirps carry a short transient.

## Denoising (`denoise.method = 'none'` by default)
Optional 4th-order Butterworth low-pass along slow time at 200 Hz. Human motion at 5.8 GHz stays within a few hundred Hz
(f_D = 2 v / lambda, about 39 Hz per m/s), so anything beyond is noise. It is off by default because whether it helps is
to be measured, not assumed.

## Normalisation (`normalize.mode = 'none'` by default)
`segment` scales each recording to unit RMS over the selected bins (uses only that recording). `global` divides by a scale
fitted on training recordings only (`dsp.fitNormalizer`), so validation and test data never influence it.

## Doppler and STFT
- Doppler FFT: Hann window, size = next power of two at or above the number of chirps.
- STFT: Hamming window of 0.2 s (200 samples at 1 kHz, 5 Hz resolution), 95% overlap (hop 10 ms), FFT of 4 x 200 points
  (1.25 Hz bin width). These are the authors' values, now settings, and are varied in Experiment C.
- The frequency axis runs from -prf/2 like `fftshift`; velocity = f_D * lambda / 2 with lambda = 5.17 cm at 5.8 GHz.
  The sign convention of the radar is not assumed.

## Figures
`show_preprocessing` writes `results/figures/preprocessing_by_activity.png` (range-time before and after, and Doppler
spectra before and after, for one recording per activity). `demo_pipeline` shows the same stages for a single recording.
