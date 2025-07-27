#!/bin/bash

set -e

echo "Setting up Grafana Alert Rules and Contact Points..."

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

GRAFANA_URL="http://localhost:3000"
AUTH="${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}"

echo "Checking Grafana connection..."
curl -s -u "$AUTH" "${GRAFANA_URL}/api/health" > /dev/null || {
    echo "Error: Cannot connect to Grafana. Make sure port-forward is running:"
    echo "kubectl port-forward svc/grafana 3000:3000 -n monitoring"
    exit 1
}

echo "Getting Prometheus datasource UID..."
PROMETHEUS_DATASOURCE_UID=$(curl -s -u "$AUTH" "${GRAFANA_URL}/api/datasources" | python -c "
import json, sys
datasources = json.load(sys.stdin)
for ds in datasources:
    if ds.get('type') == 'prometheus':
        print(ds.get('uid'))
        break
else:
    print('-')
")

export PROMETHEUS_DATASOURCE_UID
echo "Using Prometheus datasource UID: $PROMETHEUS_DATASOURCE_UID"

echo "Creating alerts folder if not exists..."
curl -X POST \
  -H "Content-Type: application/json" \
  -u "$AUTH" \
  -d '{"title":"alerts","uid":"alerts"}' \
  "${GRAFANA_URL}/api/folders" 2>/dev/null || echo "Folder likely exists, continuing..."

echo "Creating contact points from YAML..."
envsubst < k8s/grafana/provisioning/contact-points.yaml | python -c "
import yaml, json, sys
import urllib.request
from base64 import b64encode

# Load contact points YAML
data = yaml.safe_load(sys.stdin)
auth_header = 'Basic ' + b64encode('${AUTH}'.encode()).decode()

# Create contact points
for contact_point in data.get('contactPoints', []):
    print(f'Creating contact point: {contact_point.get(\"name\")}')
    
    payload = {
        'name': contact_point.get('name'),
        'type': contact_point['receivers'][0]['type'],
        'settings': contact_point['receivers'][0]['settings']
    }
    
    req = urllib.request.Request(
        '${GRAFANA_URL}/api/v1/provisioning/contact-points',
        data=json.dumps(payload).encode(),
        headers={
            'Content-Type': 'application/json',
            'Authorization': auth_header
        }
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 201:
                print(f'✓ Contact point created: {contact_point.get(\"name\")}')
            else:
                print(f'Contact point may already exist: {contact_point.get(\"name\")}')
    except Exception as e:
        print(f'Contact point creation result: {contact_point.get(\"name\")} (may already exist)')

# Update notification policy
for policy in data.get('policies', []):
    print(f'Updating notification policy to use: {policy.get(\"receiver\")}')
    
    policy_payload = {
        'receiver': policy.get('receiver'),
        'group_by': policy.get('group_by', ['alertname']),
        'group_wait': policy.get('group_wait', '10s'),
        'group_interval': policy.get('group_interval', '10s'),
        'repeat_interval': policy.get('repeat_interval', '1h'),
        'routes': policy.get('routes', [])
    }
    
    req = urllib.request.Request(
        '${GRAFANA_URL}/api/v1/provisioning/policies',
        data=json.dumps(policy_payload).encode(),
        headers={
            'Content-Type': 'application/json',
            'Authorization': auth_header
        }
    )
    req.get_method = lambda: 'PUT'
    
    try:
        with urllib.request.urlopen(req) as response:
            print(f'✓ Notification policy updated')
    except Exception as e:
        print(f'Policy update result: {str(e)}')
"

echo "Creating alert rules from YAML..."
envsubst < k8s/grafana/provisioning/alert-rules.yaml | python -c "
import yaml, json, sys
import urllib.request
from base64 import b64encode

# Load alert rules YAML
data = yaml.safe_load(sys.stdin)
auth_header = 'Basic ' + b64encode('${AUTH}'.encode()).decode()

# Process each group
for group in data.get('groups', []):
    for rule in group.get('rules', []):
        print(f'Creating alert rule: {rule.get(\"title\")}')
        
        # Build payload matching the working format
        payload = {
            'folderUID': 'alerts',
            'title': rule.get('title'),
            'condition': rule.get('condition'),
            'data': [],
            'noDataState': rule.get('noDataState', 'NoData'),
            'execErrState': rule.get('execErrState', 'Alerting'),
            'for': rule.get('for', '5m'),
            'annotations': rule.get('annotations', {}),
            'labels': rule.get('labels', {})
        }
        
        # Process data items
        for item in rule.get('data', []):
            data_item = {
                'refId': item.get('refId'),
                'queryType': item.get('queryType', ''),
                'model': item.get('model', {})
            }
            
            # Add datasourceUid
            if 'datasourceUid' in item:
                data_item['datasourceUid'] = item['datasourceUid']
            
            # Add relativeTimeRange
            if 'relativeTimeRange' in item:
                data_item['relativeTimeRange'] = item['relativeTimeRange']
            
            payload['data'].append(data_item)
        
        # Send request
        req = urllib.request.Request(
            '${GRAFANA_URL}/api/v1/provisioning/alert-rules',
            data=json.dumps(payload).encode(),
            headers={
                'Content-Type': 'application/json',
                'Authorization': auth_header
            }
        )
        
        try:
            with urllib.request.urlopen(req) as response:
                if response.status == 201:
                    print(f'✓ Successfully created: {rule.get(\"title\")}')
                else:
                    error_msg = response.read().decode()
                    print(f'✗ Error creating {rule.get(\"title\")}: {error_msg}')
        except Exception as e:
            print(f'✗ Failed to create {rule.get(\"title\")}: {str(e)}')

print('\\nAlert rules setup completed!')
"

echo ""
echo "Setup completed!"
echo ""
echo "Check Grafana:"
echo "- Alerting → Contact points (should show email-alerts)"
echo "- Alerting → Notification policies (should use email-alerts)"
echo "- Alerting → Alert rules (should show 3 rules)"
echo ""
echo "The Low CPU Test Alert should trigger immediately for testing!"
echo "Check your email for alert notifications."