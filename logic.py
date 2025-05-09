#!/usr/bin/env python3
"""
logic.py

This module contains generic data-processing logic independent of AWS Lambda or S3.
The `process` function reads a CSV file from IN_PATH, processes it, and writes results to OUT_PATH.
"""
import numpy as np

def process(in_path: str, out_path: str) -> None:
    """
    Read a CSV file from in_path, perform processing, and write output to out_path.

    Currently, this reads numeric data and computes the sum of each column.
    If the data is one-dimensional, it computes the sum of all values.

    Args:
        in_path: Filesystem path to input CSV.
        out_path: Filesystem path where the output CSV will be written.
    """
    # Load CSV data
    data = np.genfromtxt(in_path, delimiter=',')

    # Compute sum of columns (or sum of vector)
    if data.ndim == 1:
        sums = np.array([np.sum(data)])
    else:
        sums = np.sum(data, axis=0)

    # Write output as a single-row CSV
    # Convert to 2D row for consistentwriting
    np.savetxt(out_path, sums[np.newaxis, :], delimiter=',', fmt='%s')
    
if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(
        description='Process a CSV file and compute column sums.'
    )
    parser.add_argument(
        'in_path',
        help='Filesystem path to the input CSV file'
    )
    parser.add_argument(
        'out_path',
        help='Filesystem path where the output CSV file will be written'
    )
    args = parser.parse_args()
    process(args.in_path, args.out_path)