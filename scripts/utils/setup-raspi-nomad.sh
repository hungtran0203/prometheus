#!/bin/bash


# Copy the client configuration
scp -i ~/.ssh/id_rsa nomad/config/clients/ras.hcl hung@ras.local:/home/hung/nomad_client.hcl

# Start/restart Nomad
ssh -i ~/.ssh/id_rsa hung@ras.local "sudo cp ~/nomad_client.hcl /etc/nomad.d/nomad.hcl"

ssh -i ~/.ssh/id_rsa hung@ras.local "sudo systemctl restart nomad"

echo "✅ Nomad client configuration deployed to Raspberry Pi (ras.local)"
echo "Check status with: ssh hung@ras.local 'sudo systemctl status nomad || ps aux | grep nomad'" 