#!/usr/bin/env python3
import pymysql
import os

os.chdir('/opt/lpr-app')
with open('.env') as f:
    for line in f:
        if '=' in line and not line.startswith('#'):
            key, val = line.strip().split('=', 1)
            os.environ[key] = val

print(f"\nConnecting to RDS MySQL:")
print(f"  Host: {os.getenv('DB_HOST')}")
print(f"  Database: {os.getenv('DB_NAME')}")
print(f"  User: {os.getenv('DB_USER')}")

conn = pymysql.connect(
    host=os.getenv('DB_HOST'),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD'),
    database=os.getenv('DB_NAME')
)

cur = conn.cursor()

print("\n" + "="*80)
print("DATABASE VERIFICATION")
print("="*80)

# Show tables
cur.execute('SHOW TABLES')
tables = cur.fetchall()
print(f"\n✓ Tables in database: {tables}")

# Describe table
cur.execute('DESCRIBE plates')
columns = cur.fetchall()
print(f"\n✓ Table 'plates' schema:")
for col in columns:
    print(f"  - {col[0]} ({col[1]})")

# Count records
cur.execute('SELECT COUNT(*) FROM plates')
count = cur.fetchone()[0]
print(f"\n✓ Total records in 'plates' table: {count}")

# Show recent records
cur.execute('SELECT id, timestamp, plate_number, color, make, model FROM plates ORDER BY timestamp DESC LIMIT 5')
rows = cur.fetchall()
if rows:
    print(f"\n✓ Recent uploads:")
    for row in rows:
        print(f"  ID={row[0]}, Plate={row[2]}, Color={row[3]}, Time={row[1]}")

conn.close()

print("\n" + "="*80)
print("✓ RDS MySQL is working correctly!")
print("="*80 + "\n")

