#!/usr/bin/env python3
import pymysql
import os

# Load .env
os.chdir('/opt/lpr-app')
with open('.env') as f:
    for line in f:
        if '=' in line and not line.startswith('#'):
            key, val = line.strip().split('=', 1)
            os.environ[key] = val

DB_HOST = os.getenv('DB_HOST')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_NAME = os.getenv('DB_NAME')

print(f"Connecting to: {DB_HOST}")
print(f"Database: {DB_NAME}")
print(f"User: {DB_USER}")

try:
    conn = pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        connect_timeout=5
    )
    print("✓ Connection successful!")
    
    cur = conn.cursor()
    cur.execute('SHOW TABLES')
    tables = cur.fetchall()
    print(f"Tables: {tables}")
    
    if not tables:
        print("\nNo tables found. Initializing database...")
        with open('/opt/lpr-app/deployment/init-db.sql') as f:
            sql = f.read()
            for statement in sql.split(';'):
                statement = statement.strip()
                if statement:
                    cur.execute(statement)
        conn.commit()
        print("✓ Database initialized!")
    
    conn.close()
    
except pymysql.err.OperationalError as e:
    print(f"✗ Connection failed: {e}")
    exit(1)

