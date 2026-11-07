"""SQLite real para os testes locais do canal sqflite, sem acessar dados do app."""
import json
import sqlite3
import sys

sys.stdin.reconfigure(encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8')

db = sqlite3.connect(':memory:', isolation_level=None)

def execute(request):
    method = request['method']
    if method == 'batch':
        results = []
        for operation in request['operations']:
            results.append({'result': execute(operation)})
        return None if request.get('noResult') else results
    cursor = db.execute(request['sql'], request.get('arguments') or [])
    if method == 'query':
        return {'columns': [c[0] for c in cursor.description], 'rows': cursor.fetchall()}
    if method == 'insert':
        return cursor.lastrowid
    if method == 'update':
        return cursor.rowcount

for line in sys.stdin:
    try:
        print(json.dumps({'result': execute(json.loads(line))}), flush=True)
    except Exception as exc:
        print(json.dumps({'error': str(exc)}), flush=True)
