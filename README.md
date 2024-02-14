# Rancher K3s Deployment on Crusoe Cloud

## Known Issues
If the Terraform below fails contact support@crusoecloud.com for help.

## Deployment
Modify the `locals` in the `main.tf` resource YAML file.
```
locals {
  my_ssh_privkey_path="</path/to/priv.key"
  my_ssh_pubkey="<pub_key>"
  worker_instance_type = "h100-80gb-sxm-ib.8x"
  worker_image = "ubuntu22.04-nvidia-sxm-docker:latest"
  ib_partition_id = "6dcef748-dc30-49d8-9a0b-6ac87a27b4f8"
  count_workers = 2
  headnode_instance_type="c1a.8x"
  deploy_location = "us-east1-a"
...
}
```
And then apply, to provision resources
```
terraform init
terraform plan
terraform apply
```

