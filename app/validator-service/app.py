import os
import json
import boto3
from flask import Flask, request, jsonify
from functools import lru_cache

app = Flask(__name__)

# AWS clients
ssm_client = boto3.client('ssm')
sqs_client = boto3.client('sqs')

SSM_TOKEN_PARAMETER = os.environ.get('SSM_TOKEN_PARAMETER', '/app/token')
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')

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
    return provided_token == valid_token

def validate_payload(data):
    """Validate that the payload has the required 4 text fields"""
    if not isinstance(data, dict):
        return False, "Payload must be a JSON object"
    
    # Check if there are exactly 4 fields and all are strings
    if len(data) != 4:
        return False, "Payload must contain exactly 4 fields"
    
    for key, value in data.items():
        if not isinstance(value, str):
            return False, f"Field '{key}' must be a string"
    
    return True, None

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"}), 200

@app.route('/', methods=['POST'])
def process_request():
    """Main endpoint to process incoming requests"""
    try:
        # Get JSON payload
        request_body = request.get_json()
        if not request_body:
            return jsonify({"error": "Missing JSON payload"}), 400

        # Get token from body
        token = request_body.get('token')
        if not token:
            return jsonify({"error": "Missing token in body"}), 401
        
        # Validate token
        if not validate_token(token):
            return jsonify({"error": "Invalid token"}), 401
        
        # Get data object
        data = request_body.get('data')
        if not data:
            return jsonify({"error": "Missing 'data' field in payload"}), 400
        
        # Validate payload data
        is_valid, error_msg = validate_payload(data)
        if not is_valid:
            return jsonify({"error": error_msg}), 400
        
        # Send to SQS
        try:
            response = sqs_client.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(data)
            )
            app.logger.info(f"Message sent to SQS: {response['MessageId']}")
            
            return jsonify({
                "status": "success",
                "message_id": response['MessageId']
            }), 200
            
        except Exception as e:
            app.logger.error(f"Error sending message to SQS: {str(e)}")
            return jsonify({"error": "Failed to queue message"}), 500
            
    except Exception as e:
        app.logger.error(f"Unexpected error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
