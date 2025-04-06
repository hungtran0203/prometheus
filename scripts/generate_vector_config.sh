#!/bin/bash

# Script to generate Vector configuration with transforms for each proxy app
# Usage: ./scripts/generate_vector_config.sh

echo "🔧 Generating Vector configuration for all proxy apps..."

# Check if Vector template exists
if [ ! -f "templates/vector.toml.template" ]; then
    echo "❌ Error: Vector template file not found!"
    exit 1
fi

# Create vector directory if it doesn't exist
mkdir -p vector

# Create a temporary file for building the transforms
tmp_file=$(mktemp)
app_count=0

# Copy the template to our output file
cp templates/vector.toml.template "$tmp_file"

# First check NGINX server configs to get app names and target ports
echo "📊 Scanning Nginx configurations for target ports..."
app_transforms=""

if [ -d "nginx/servers" ]; then
    for server_file in nginx/servers/*.conf; do
        # Skip main.conf or if file doesn't exist
        if [ ! -f "$server_file" ] || [ "$(basename "$server_file")" == "main.conf" ]; then
            continue
        fi
        
        app_name=$(basename "$server_file" .conf)
        # Find target port (the port that is being forwarded to)
        target_port=$(grep "proxy_pass" "$server_file" | grep -o 'http://host.docker.internal:[0-9]*' | grep -o '[0-9]*' | head -1)
        
        if [ -n "$app_name" ] && [ -n "$target_port" ]; then
            echo "  ✅ Found app: $app_name with target port: $target_port"
            
            # Add transform section for this app
            app_transforms+=$(cat << EOF

[transforms.${app_name}_filter]
type = "filter"
inputs = ["docker_source"]
condition = '.container_name == "${app_name}-exporter" || .message contains "port=${target_port}"'

[transforms.${app_name}_parser]
type = "remap"
inputs = ["${app_name}_filter"]
source = '''
  .app = "${app_name}"
  .target_port = "${target_port}"
  .host = get_hostname() ?? "unknown"
'''

EOF
)
            app_count=$((app_count + 1))
        else
            echo "  ⚠️ Could not determine target port for $app_name"
        fi
    done
else
    echo "  ⚠️ Nginx servers directory not found."
fi

# Generate the final Vector configuration
if [ $app_count -gt 0 ]; then
    # Replace placeholder with transforms
    echo "${app_transforms}" > vector/app_transforms.toml
    
    # Generate complete config file
    awk '
    {
        if ($0 ~ /# APP_TRANSFORMS_PLACEHOLDER/) {
            system("cat vector/app_transforms.toml")
        } else {
            print $0
        }
    }' "$tmp_file" > vector/vector.toml
    
    # Clean up
    rm -f "$tmp_file" vector/app_transforms.toml
    
    echo "✅ Generated Vector configuration with $app_count app transforms: vector/vector.toml"
else
    echo "⚠️ No apps found to configure for Vector. Creating default config."
    # Create a simple default config with placeholder comment
    awk '{
        if ($0 ~ /# APP_TRANSFORMS_PLACEHOLDER/) {
            print "# No app transforms found"
        } else {
            print $0
        }
    }' "$tmp_file" > vector/vector.toml
    rm -f "$tmp_file"
fi

exit 0 