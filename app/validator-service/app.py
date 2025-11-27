import os
import json
import boto3
from flask import Flask, request, jsonify, Response
from functools import lru_cache
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

ssm_client = boto3.client('ssm')
sqs_client = boto3.client('sqs')

SSM_TOKEN_PARAMETER = os.environ.get('SSM_TOKEN_PARAMETER', '/app/token')
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')

# Metrics
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'Request duration in seconds', ['method', 'endpoint'])
TOKEN_VALIDATION_TOTAL = Counter('validator_token_validation_total', 'Total number of token validations', ['status'])
PAYLOAD_VALIDATION_TOTAL = Counter('validator_payload_validation_total', 'Total number of payload validations', ['status'])
SQS_SENT_TOTAL = Counter('validator_sqs_sent_total', 'Total number of messages sent to SQS', ['status'])

# Initialize metrics
TOKEN_VALIDATION_TOTAL.labels(status='valid')
TOKEN_VALIDATION_TOTAL.labels(status='invalid')
PAYLOAD_VALIDATION_TOTAL.labels(status='valid')
PAYLOAD_VALIDATION_TOTAL.labels(status='invalid_type')
PAYLOAD_VALIDATION_TOTAL.labels(status='invalid_length')
PAYLOAD_VALIDATION_TOTAL.labels(status='invalid_field_type')
SQS_SENT_TOTAL.labels(status='success')
SQS_SENT_TOTAL.labels(status='error')

@lru_cache(maxsize=1)
def get_valid_token():
    """Fetch and cache the valid token from SSM Parameter Store"""
    try:
        response = ssm_client.get_parameter(
            Name=SSM_TOKEN_PARAMETER,
            WithDecryption=True
        )
        return response['Parameter']['Value']
    except Exception as e:
        app.logger.error(f"Error fetching token from SSM: {str(e)}")
        raise

def validate_token(provided_token):
    """Validate the provided token against the stored token"""
    valid_token = get_valid_token()
    is_valid = provided_token == valid_token
    TOKEN_VALIDATION_TOTAL.labels(status='valid' if is_valid else 'invalid').inc()
    return is_valid

def validate_payload(data):
    """Validate that the payload has the required 4 text fields"""
    if not isinstance(data, dict):
        PAYLOAD_VALIDATION_TOTAL.labels(status='invalid_type').inc()
        return False, "Payload must be a JSON object"
    
    # Check if there are exactly 4 fields and all are strings
    if len(data) != 4:
        PAYLOAD_VALIDATION_TOTAL.labels(status='invalid_length').inc()
        return False, "Payload must contain exactly 4 fields"
    
    for key, value in data.items():
        if not isinstance(value, str):
            PAYLOAD_VALIDATION_TOTAL.labels(status='invalid_field_type').inc()
            return False, f"Field '{key}' must be a string"
    
    PAYLOAD_VALIDATION_TOTAL.labels(status='valid').inc()
    return True, None

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"}), 200

@app.route('/metrics')
def metrics():
    """Expose Prometheus metrics"""
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route('/', methods=['POST'])
def process_request():
    """Main endpoint to process incoming requests"""
    try:
        with REQUEST_DURATION.labels(method='POST', endpoint='/').time():
            request_body = request.get_json()
        if not request_body:
            return jsonify({"error": "Missing JSON payload"}), 400

        token = request_body.get('token')
        if not token:
            return jsonify({"error": "Missing token in body"}), 401
        
        if not validate_token(token):
            return jsonify({"error": "Invalid token"}), 401
        
        data = request_body.get('data')
        if not data:
            return jsonify({"error": "Missing 'data' field in payload"}), 400
        
        is_valid, error_msg = validate_payload(data)
        if not is_valid:
            return jsonify({"error": error_msg}), 400
        
        try:
            response = sqs_client.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(data)
            )
            app.logger.info(f"Message sent to SQS: {response['MessageId']}")
            SQS_SENT_TOTAL.labels(status='success').inc()
            
            return jsonify({
                "status": "success",
                "message_id": response['MessageId']
            }), 200
            
        except Exception as e:
            app.logger.error(f"Error sending message to SQS: {str(e)}")
            SQS_SENT_TOTAL.labels(status='error').inc()
            return jsonify({"error": "Failed to queue message"}), 500
            
    except Exception as e:
        app.logger.error(f"Unexpected error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
