#!/usr/bin/env python3
import pymysql
import os

os.chdir('/opt/lpr-app')
with open('.env') as f:
    for line in f:
        if '=' in line and not line.startswith('#'):
            key, val = line.strip().split('=', 1)
            os.environ[key] = val

conn = pymysql.connect(
    host=os.getenv('DB_HOST'),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD'),
    database=os.getenv('DB_NAME')
)

cur = conn.cursor()
cur.execute('SELECT * FROM plates ORDER BY timestamp DESC LIMIT 10')
rows = cur.fetchall()

print(f"\n{'='*80}")
print(f"Recent uploads in RDS MySQL:")
print(f"{'='*80}\n")

if rows:
    print(f"{'ID':<5} {'Timestamp':<20} {'Plate':<10} {'Color':<10} {'Make':<15} {'Model':<15}")
    print("-" * 80)
    for row in rows:
        print(f"{row[0]:<5} {str(row[1]):<20} {row[2] or 'N/A':<10} {row[3] or 'N/A':<10} {row[4] or 'N/A':<15} {row[5] or 'N/A':<15}")
    print(f"\nTotal: {len(rows)} records")
else:
    print("No records found in database!")

conn.close()

