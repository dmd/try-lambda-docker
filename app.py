import os
import boto3
import numpy as np
import tempfile
from urllib.parse import unquote_plus

s3_client = boto3.client('s3')

# Prefixes for input and output keys
IN_PREFIX = os.environ.get('IN_PREFIX', 'try-lambda/in/')
OUT_PREFIX = os.environ.get('OUT_PREFIX', 'try-lambda/out/')

def lambda_handler(event, context):
    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        if not key.startswith(IN_PREFIX):
            continue
        filename = key[len(IN_PREFIX):]
        if not filename:
            continue
        # Download the file from S3
        download_path = os.path.join(tempfile.gettempdir(), filename)
        s3_client.download_file(bucket, key, download_path)
        # Load CSV data
        data = np.genfromtxt(download_path, delimiter=',')
        # Compute sum of each column
        if data.ndim == 1:
            sums = np.array([np.sum(data)])
        else:
            sums = np.sum(data, axis=0)
        # Write output CSV
        output_path = os.path.join(tempfile.gettempdir(), filename)
        np.savetxt(output_path, sums[np.newaxis, :], delimiter=',', fmt='%s')
        # Upload the result back to S3
        out_key = OUT_PREFIX + filename
        s3_client.upload_file(output_path, bucket, out_key)
    return {'status': 'complete'}