import os
import json
import time
import boto3
from datetime import datetime
from prometheus_client import start_http_server, Counter, Histogram

sqs_client = boto3.client('sqs')
s3_client = boto3.client('s3')

SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '10'))
METRICS_PORT = int(os.environ.get('METRICS_PORT', '8000'))

# Metrics
MESSAGES_PROCESSED_TOTAL = Counter('uploader_messages_processed_total', 'Total number of messages processed', ['status'])
PROCESSING_DURATION = Histogram('uploader_processing_duration_seconds', 'Time taken to process a message')
S3_UPLOAD_TOTAL = Counter('uploader_s3_upload_total', 'Total number of files uploaded to S3', ['status'])

def process_message(message):
    """Process a single SQS message and upload to S3"""
    try:
        with PROCESSING_DURATION.time():
            body = json.loads(message['Body'])
        
        # Generate S3 key with timestamp
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H%M%S')
        message_id = message['MessageId']
        s3_key = f"messages/{timestamp}_{message_id}.json"
        
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=json.dumps(body, indent=2),
            ContentType='application/json'
        )
        
        print(f"Successfully uploaded message {message_id} to s3://{S3_BUCKET_NAME}/{s3_key}")
        S3_UPLOAD_TOTAL.labels(status='success').inc()
        
        sqs_client.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=message['ReceiptHandle']
        )
        
        print(f"Deleted message {message_id} from queue")
        MESSAGES_PROCESSED_TOTAL.labels(status='success').inc()
        return True
        
    except Exception as e:
        print(f"Error processing message: {str(e)}")
        MESSAGES_PROCESSED_TOTAL.labels(status='error').inc()
        return False

def poll_queue():
    """Poll SQS queue for messages"""
    print(f"Starting metrics server on port {METRICS_PORT}")
    start_http_server(METRICS_PORT)
    
    print(f"Starting to poll queue: {SQS_QUEUE_URL}")
    print(f"Uploading to bucket: {S3_BUCKET_NAME}")
    print(f"Poll interval: {POLL_INTERVAL} seconds")
    
    while True:
        try:
            response = sqs_client.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20, 
                VisibilityTimeout=30
            )
            
            messages = response.get('Messages', [])
            
            if messages:
                print(f"Received {len(messages)} message(s)")
                for message in messages:
                    process_message(message)
            else:
                print("No messages in queue")
            
            time.sleep(POLL_INTERVAL)
            
        except Exception as e:
            print(f"Error polling queue: {str(e)}")
            time.sleep(POLL_INTERVAL)

if __name__ == '__main__':
    poll_queue()
