# Working with MATLAB Online (drag and drop)

Code is edited in the project folder on the Mac. MATLAB Online is used to run it.

## First time
1. Open https://drive.mathworks.com and sign in.
2. Create a folder `project-dsp`.
3. Drag these from the project folder into it: `src`, `scripts`, `tests`, `configs`, `startup.m`.
   (Do not upload `openspec`, `.opencode`, `tools`, or any dataset folder.)
4. Open MATLAB Online (https://matlab.mathworks.com). In the Current Folder panel, open `MATLAB Drive/project-dsp`.
5. In the Command Window run:
   ```matlab
   startup
   check_environment
   run_all_tests
   ```

## After each change
Drag only the files or folders that changed into the same Drive folder and choose to replace.
Then run `run_all_tests` again. If a test fails, copy the Command Window output
(or open `results/test_log.txt`) and paste it into the chat.

## Data (once)
In MATLAB Drive, inside `project-dsp`, create a folder `data`.
1. Drag the whole `samples` folder (from `project-dsp-data/upload/`) into `project-dsp/data/`.
2. Drag the seven `*_Dataset.zip` files into `project-dsp/data/`. They total about 3.1 GB, so upload
   a few at a time; start with `2_March_2017_Dataset.zip` (87 MB) if you want to try things quickly.
3. In MATLAB Online run `unpack_data`, then `build_dataset_index`.
4. You can delete the zips afterwards to free Drive space; the data stays in `data/converted`.

## Demo and figure scripts (need the data in `data/converted`)
| Run | What you get |
|---|---|
| `demo_pipeline` | Five figures, one per stage, on one recording. `demo_pipeline(Save=true)` also saves PNGs to `results/figures`. |
| `show_class_gallery` | `class_gallery.png`: one spectrogram per activity, same person and colour scale. |
| `show_preprocessing` | `preprocessing_by_activity.png`: before/after clutter removal for one recording per activity. |
| `show_range_time` | `range_time_by_activity.png`. |
Figures appear in the MATLAB Online window; saved PNGs are in `results/figures` (download them from MATLAB Drive).

## If figure windows come up blank
In some MATLAB Online sessions a floating figure window opens empty and the command blocks until it is closed.
The scripts can work without opening any window:

    demo_pipeline(Save=true, Show=false)
    show_class_gallery(Show=false)
    show_preprocessing(Show=false)
    show_range_time(Show=false)

The PNGs are written to `results/figures` (download them from MATLAB Drive). The experiment scripts (`experiment_B`,
`experiment_C`) never open windows. Signing out of MATLAB Online and back in also clears the problem.
