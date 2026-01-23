import os
import sys
import logging
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

# 1. Enhanced Logging Configuration
logging.basicConfig(
    level=logging.DEBUG,
    format='[%(asctime)s] %(levelname)s in %(module)s: %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Config
ACTIVE_PROFILE = os.getenv('ACTIVE_PROFILE', 'primary')
DB_USER = os.getenv('DB_USER')
DB_PASS = os.getenv('DB_PASSWORD')
DB_NAME = os.getenv('DB_NAME')

def get_db_connection():
    host_env = f"DB_HOST_{ACTIVE_PROFILE.upper()}"
    db_host = os.getenv(host_env)
    
    # DEBUG: Log connection attempt (do not log the password!)
    logger.debug(f"Attempting DB connection to HOST: {db_host}, USER: {DB_USER}, DB: {DB_NAME}")
    
    if not db_host:
        logger.error(f"Environment variable {host_env} is NOT SET.")
        raise ValueError(f"Missing database host for profile: {ACTIVE_PROFILE}")

    conn_string = (
        f"host={db_host} "
        f"dbname={DB_NAME} "
        f"user={DB_USER} "
        f"password={DB_PASS} "
        f"sslmode=require"
    )
    return psycopg2.connect(conn_string)

@app.route('/data')
def get_data():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        logger.debug("Executing query: SELECT id, name FROM items LIMIT 10;")
        cur.execute("SELECT id, name FROM items LIMIT 10;")
        
        rows = cur.fetchall()
        logger.info(f"Successfully retrieved {len(rows)} rows from {ACTIVE_PROFILE} DB.")
        
        cur.close()
        conn.close()
        return jsonify({
            "profile": ACTIVE_PROFILE, 
            "status": "success",
            "count": len(rows),
            "data": rows
        })
    except Exception as e:
        # DEBUG: Log the full stack trace for the developer
        logger.exception("Database access failed") 
        return jsonify({
            "error": str(e), 
            "profile": ACTIVE_PROFILE,
            "hint": "Check if DB host is reachable and credentials are correct"
        }), 500

# 2. New Debug Endpoint
@app.route('/debug')
def debug_info():
    """Returns non-sensitive environment info for troubleshooting"""
    return jsonify({
        "ACTIVE_PROFILE": ACTIVE_PROFILE,
        "DB_USER": DB_USER,
        "DB_NAME": DB_NAME,
        "PRIMARY_HOST": os.getenv('DB_HOST_PRIMARY'),
        "SECONDARY_HOST": os.getenv('DB_HOST_SECONDARY'),
        "PYTHON_VERSION": sys.version,
        "PLATFORM": sys.platform
    })

# 3. Health Check (Recommended for K8s Liveness/Readiness)
# Change the route to match what is being called
@app.route('/healthz')
@app.route('/health') # Keep /health as an alias
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == '__main__':
    # In 2026, use debug=True only for local dev, not in AKS
    app.run(host='0.0.0.0', port=8080)
