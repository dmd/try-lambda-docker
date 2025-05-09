import os
import boto3
import subprocess
import tempfile
from urllib.parse import unquote_plus

# S3 client
s3_client = boto3.client('s3')
## Command to invoke external logic processor
LOGIC_CMD = os.environ.get('LOGIC_CMD', './logic.py')

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
        # Process the file and write to output_path via external logic command
        output_path = os.path.join(tempfile.gettempdir(), filename)
        subprocess.run([LOGIC_CMD, download_path, output_path], check=True)
        # Upload the result back to S3
        out_key = OUT_PREFIX + filename
        s3_client.upload_file(output_path, bucket, out_key)
    return {'status': 'complete'}