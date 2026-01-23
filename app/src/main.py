import os
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

# Config
ACTIVE_PROFILE = os.getenv('ACTIVE_PROFILE', 'primary')
DB_USER = os.getenv('DB_USER')
DB_PASS = os.getenv('DB_PASSWORD') # From K8s Secret
DB_NAME = os.getenv('DB_NAME')

def get_db_connection():
    # Pick host based on active profile
    host_env = f"DB_HOST_{ACTIVE_PROFILE.upper()}"
    db_host = os.getenv(host_env)
    
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
        cur.execute("SELECT id, name FROM items LIMIT 10;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify({"profile": ACTIVE_PROFILE, "data": rows})
    except Exception as e:
        return jsonify({"error": str(e), "profile": ACTIVE_PROFILE}), 500
