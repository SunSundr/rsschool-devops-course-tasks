#!/bin/bash

set -e

echo "Installing alert rules only from YAML configuration..."

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

GRAFANA_URL="http://localhost:3000"
ALERT_RULES_FILE="k8s/grafana/provisioning/alert-rules.yaml"
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

echo "Deleting all existing alert rules..."
curl -s -u "$AUTH" "${GRAFANA_URL}/api/v1/provisioning/alert-rules" | python -c "
import json, sys
import urllib.request
from base64 import b64encode

rules = json.load(sys.stdin)
auth_header = 'Basic ' + b64encode('${AUTH}'.encode()).decode()

print(f'Found {len(rules)} existing rules to delete')
for rule in rules:
    rule_uid = rule.get('uid')
    if rule_uid:
        print(f'Deleting: {rule.get(\"title\", \"Unknown\")}')
        req = urllib.request.Request(
            f'${GRAFANA_URL}/api/v1/provisioning/alert-rules/{rule_uid}',
            headers={'Authorization': auth_header}
        )
        req.get_method = lambda: 'DELETE'
        try:
            urllib.request.urlopen(req)
        except Exception as e:
            print(f'Error deleting rule: {e}')
"

echo "Creating new alert rules from YAML..."
envsubst < ${ALERT_RULES_FILE} | python -c "
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
            'ruleGroup': group.get('name', 'kubernetes-alerts'),
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
            
            # Add relativeTimeRange only for data queries (refId A)
            if 'relativeTimeRange' in item and item.get('refId') == 'A':
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

print('\\nAlert rules installation completed!')
"

echo ""
echo "Alert rules installation completed!"
echo ""
echo "Check Grafana:"
echo "- Alerting → Alert rules (should show 2 rules)"
echo "- Rules should have graphs and proper evaluation"
echo "- High CPU: Triggers when CPU > 80% for 5 minutes"
echo "- High Memory: Triggers when Memory > 85% for 5 minutes"