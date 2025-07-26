import pytest
from main import app
import json

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_hello_endpoint(client):
    response = client.get('/')
    assert response.status_code == 200
    assert b'Flask App' in response.data

def test_health_endpoint(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert 'timestamp' in data
    assert 'hostname' in data
    assert 'version' in data

def test_info_endpoint(client):
    response = client.get('/info')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'python_version' in data
    assert 'flask_version' in data
    assert 'environment' in data