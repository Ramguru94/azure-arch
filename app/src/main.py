#!/usr/bin/env python3
"""
Simple Hello World Flask Application
"""
from flask import Flask, jsonify
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Application health and metadata
APP_NAME = os.getenv('APP_NAME', 'hello-world')
APP_VERSION = os.getenv('APP_VERSION', '1.0.0')
ENVIRONMENT = os.getenv('ENVIRONMENT', 'dev')


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    logger.info('Health check request received')
    return jsonify({
        'status': 'healthy',
        'app': APP_NAME
    }), 200


@app.route('/healthz', methods=['GET'])
def healthz():
    """Kubernetes liveness probe endpoint"""
    return '', 204


@app.route('/', methods=['GET'])
def hello():
    """Main hello world endpoint"""
    logger.info('Hello world request received')
    return jsonify({
        'message': 'Hello World!',
        'app': APP_NAME,
        'version': APP_VERSION,
        'environment': ENVIRONMENT
    }), 200


@app.route('/api/info', methods=['GET'])
def info():
    """Application information endpoint"""
    return jsonify({
        'name': APP_NAME,
        'version': APP_VERSION,
        'environment': ENVIRONMENT
    }), 200


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'error': 'Not Found',
        'message': 'The requested resource was not found'
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f'Internal server error: {error}')
    return jsonify({
        'error': 'Internal Server Error',
        'message': 'An unexpected error occurred'
    }), 500


if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    logger.info(f'Starting {APP_NAME} on port {port}')
    app.run(host='0.0.0.0', port=port, debug=False)
