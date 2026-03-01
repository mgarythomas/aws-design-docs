import yaml
import copy

with open('/Users/gary/Documents/Repos/aws-design-docs/lambdas/reference-data/api/reference-data-openapi.yaml', 'r') as f:
    orig_spec = yaml.safe_load(f)

# Create Edge Spec
edge_spec = copy.deepcopy(orig_spec)
edge_spec['info']['title'] = "Reference Data DMZ API"
edge_spec['info']['description'] = "Public-facing Edge API for querying reference data. Routes traffic to internal VPC securely."

for path, methods in edge_spec.get('paths', {}).items():
    for method, op in methods.items():
        if method in ['get', 'post', 'put', 'delete']:
            # Replace integration to point to the single Edge Lambda
            op['x-amazon-apigateway-integration'] = {
                'type': 'aws_proxy',
                'httpMethod': 'POST',
                'uri': 'arn:aws:apigateway:${stageVariables.region}:lambda:path/2015-03-31/functions/${stageVariables.edgeLambdaArn}/invocations',
                'passthroughBehavior': 'when_no_match'
            }
            # Add basic caching parameters based on path parameters (if any exist)
            cache_keys = []
            for param in op.get('parameters', []):
                if param.get('required'):
                    in_type = param.get('in', 'path')
                    name = param.get('name')
                    cache_keys.append(f"method.request.{in_type}.{name}")
            
            if cache_keys:
                op['x-amazon-apigateway-integration']['cacheNamespace'] = f"cache{path.replace('/', '').replace('{', '').replace('}', '').replace('-', '')}"
                op['x-amazon-apigateway-integration']['cacheKeyParameters'] = cache_keys

with open('/Users/gary/Documents/Repos/aws-design-docs/lambdas/reference-data-edge/openapi.yaml', 'w') as f:
    yaml.dump(edge_spec, f, sort_keys=False, default_flow_style=False)


# Create Core Spec
core_spec = copy.deepcopy(orig_spec)
core_spec['info']['title'] = "Reference Data Internal API"
core_spec['info']['description'] = "Private Core API for executing reference data queries against the RDS Proxied database."

for path, methods in core_spec.get('paths', {}).items():
    for method, op in methods.items():
        if method in ['get', 'post', 'put', 'delete']:
            # The original spec used direct ${LambdaArn} in the uri string, which is good.
            # But we want to use stageVariables for terraform injection if possible,
            # or keep it as is. Let's standardize them to use stage variables.
            orig_uri = op.get('x-amazon-apigateway-integration', {}).get('uri', '')
            # Extract ${FunctionArn} and replace with ${stageVariables.FunctionArn}
            import re
            new_uri = re.sub(r'\$\{([^:}]+)\}', lambda m: f"${{stageVariables.{m.group(1)}}}" if "AWS::Region" not in m.group(1) else "${stageVariables.region}", orig_uri)
            
            op['x-amazon-apigateway-integration'] = {
                'type': 'aws_proxy',
                'httpMethod': 'POST',
                'uri': new_uri,
                'passthroughBehavior': 'when_no_match'
            }

with open('/Users/gary/Documents/Repos/aws-design-docs/lambdas/reference-data-core/openapi.yaml', 'w') as f:
    yaml.dump(core_spec, f, sort_keys=False, default_flow_style=False)

print("Successfully generated edge and core openapi specs.")
