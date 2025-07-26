from flask import Flask
import os
import sys
import socket
from datetime import datetime
import importlib.metadata
from metrics import init_metrics

app = Flask(__name__)
init_metrics(app)

@app.route('/')
def hello():
    hostname = socket.gethostname()
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')
    
    return f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Flask App - K3s Deployment</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
            .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            .header {{ color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 20px; margin-bottom: 30px; }}
            .info {{ background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 10px 0; }}
            .success {{ color: #27ae60; font-weight: bold; }}
            .links {{ margin-top: 30px; }}
            .links a {{ display: inline-block; margin: 10px 15px 10px 0; padding: 10px 20px; background: #3498db; color: white; text-decoration: none; border-radius: 5px; }}
            .links a:hover {{ background: #2980b9; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 Flask App</h1>
                <p class="success">✅ K3s Kubernetes Cluster • ✅ Helm Chart • ✅ Docker Container</p>
            </div>
            
            <div class="info">
                <h3>📊 Deployment Information</h3>
                <p><strong>Hostname:</strong> {hostname}</p>
                <p><strong>Timestamp:</strong> {timestamp}</p>
                <p><strong>Environment:</strong> AWS Cloud (K3s)</p>
                <p><strong>Container:</strong> Python 3.14 Alpine</p>
            </div>
            
            <div class="info">
                <h3>🏗️ Infrastructure Stack</h3>
                <p>• <strong>Infrastructure:</strong> Terraform (AWS VPC, EC2, Security Groups)</p>
                <p>• <strong>Kubernetes:</strong> K3s Cluster (Master + Worker nodes)</p>
                <p>• <strong>Deployment:</strong> Helm Chart with custom values</p>
                <p>• <strong>Networking:</strong> NodePort service with port-forward</p>
                <p>• <strong>Registry:</strong> DockerHub (sunsundr/flask-app)</p>
            </div>
            
            <div class="links">
                <a href="/health">Health Check</a>
                <a href="/info">System Info</a>
                <a href="https://github.com/SunSundr/rsschool-devops-course-tasks" target="_blank">GitHub Repo</a>
            </div>
        </div>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    return {
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'version': '1.0.0'
    }

@app.route('/info')
def info():
    try:
        flask_version = importlib.metadata.version('flask')
    except Exception:
        flask_version = 'unknown'
    
    return {
        'hostname': socket.gethostname(),
        'python_version': sys.version.split()[0],
        'flask_version': flask_version,
        'environment': os.environ.get('FLASK_ENV', 'production'),
        'timestamp': datetime.now().isoformat()
    }

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)