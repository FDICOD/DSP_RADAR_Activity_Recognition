"""One-off data-prep tool: convert the Glasgow text .dat files to compact .mat files.

The raw text data is about 15 GB; as uint16 I/Q pairs it is about 5 GB, which can
be uploaded to MATLAB Drive. This tool does NOT replace the MATLAB loader
(src/+dsp/loadDat.m), which must read the original .dat format as well.

Each output file holds:
  I, Q     uint16 column vectors (ADC counts, exactly as in the text file)
  fc       carrier frequency [Hz]
  Tc_ms    chirp duration [ms]
  nts      samples per chirp
  bw       bandwidth [Hz]
  srcname  original file name

Files that are byte-identical copies made by hand (names containing "(2)" or
" - Copy") are skipped. A manifest.csv listing every file is written.

Usage:
  python convert_dat_to_mat.py <extracted_dir> <output_dir>
"""
import csv
import os
import re
import sys

import numpy as np
from scipy.io import savemat

NAME = re.compile(r"^(\d)P(\d+)A(\d+)R(\d+)\.dat$", re.IGNORECASE)


def read_dat(path):
    text = open(path, "rb").read().decode("ascii")
    lines = text.split("\r\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    header = [float(x) for x in lines[:4]]
    body = " ".join(lines[4:]).replace("i", "").replace("+", " +").replace("-", " -")
    values = np.fromstring(body, sep=" ")
    if values.size % 2:
        raise ValueError("odd number of values in " + path)
    return header, values[0::2], values[1::2]


def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    rows = []
    for session in sorted(d for d in os.listdir(src) if os.path.isdir(os.path.join(src, d))):
        sdir = os.path.join(src, session)
        odir = os.path.join(dst, session)
        os.makedirs(odir, exist_ok=True)
        for fname in sorted(os.listdir(sdir)):
            if not fname.lower().endswith(".dat"):
                continue
            if "(2)" in fname or " - Copy" in fname:
                rows.append([session, fname, "", "", "", "", "", "", "", "", "", "skipped_duplicate"])
                continue
            header, i_vals, q_vals = read_dat(os.path.join(sdir, fname))
            lo = min(i_vals.min(), q_vals.min())
            hi = max(i_vals.max(), q_vals.max())
            if lo < 0 or hi > 65535 or not (np.all(i_vals == np.round(i_vals)) and np.all(q_vals == np.round(q_vals))):
                raise ValueError("values outside uint16 or non-integer in " + fname)
            fc, tc_ms, nts, bw = header
            savemat(
                os.path.join(odir, fname[:-4] + ".mat"),
                {
                    "I": i_vals.astype(np.uint16).reshape(-1, 1),
                    "Q": q_vals.astype(np.uint16).reshape(-1, 1),
                    "fc": fc,
                    "Tc_ms": tc_ms,
                    "nts": nts,
                    "bw": bw,
                    "srcname": fname,
                },
                do_compression=True,
            )
            m = NAME.match(fname)
            k, p, a, r = m.groups() if m else ("", "", "", "")
            n = i_vals.size
            rows.append([session, fname, k, p, a, r, n, n / nts, int(lo), int(hi), fc, "ok" if m else "name_not_matching"])
        print("done", session, flush=True)
    with open(os.path.join(dst, "manifest.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["session", "file", "K", "P", "A", "R", "samples", "chirps", "min", "max", "fc_hz", "status"])
        w.writerows(rows)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
