# week10summary
# Week 10 – Final Summary Task: Mini DevOps Project
this is built on top of 'week9summary' - https://github.com/Benny902/week9summary  

<details><summary>week 9</summary>


### GitHubSecrets Required (Settings > Secrets and variables > Actions): 
- VM_SSH_KEY → Contents of the private ~/.ssh/id_rsa file (not the .pub!)
- AZURE_CREDENTIALS → A service principal in JSON format to allow azure/login

<br>

Create `VM_SSH_KEY` with:
```bash
ssh-keygen -t rsa -b 2048
```
- copy the Contents of the private ~/.ssh/id_rsa file (not the .pub!) into the `VM_SSH_KEY` secret

<br>

Create `AZURE_CREDENTIALS` with:
```bash
# to login:
az login --use-device-code

# to see list of accounts associated and verify which is set as default.
az account list --output table

# then create with this: (replaced <SubscriptionId> with mine)
az ad sp create-for-rbac \
  --name "gh-actions" \
  --role contributor \
  --scopes "/subscriptions/<SubscriptionId>" \
  --sdk-auth
```
- copy the entire json output into the `AZURE_CREDENTIALS` secret

---

### Install and Configure Terraform

#### Install terraform
```bash
sudo snap install terraform --classic
```

- check that install successful `terraform -v`

---

### Create initial main.tf and initialize:
```bash
touch main.tf
terraform init
```

### Make Modular main.tf and Define Infrastructure Resources

#### Modular folder structure for modules  

```css
terraform-rg/
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/
    ├── resource_group/
    │   └── main.tf
    │   └── variables.tf
    │   └── outputs.tf
    ├── network/
    │   └── main.tf
    │   └── variables.tf
    │   └── outputs.tf
    └── vm/
        └── main.tf
        └── variables.tf
        └── cloud-init.sh
```

<details> <summary> Root `main.tf`: </summary>

```bash
provider "azurerm" {
  features {}
}

module "rg" {
  source   = "./modules/resource_group"
  name     = "devops-week9-rg"
  location = var.location
}

module "network" {
  source  = "./modules/network"
  rg_name = module.rg.name
  location = var.location
}

module "vm" {
  source           = "./modules/vm"
  rg_name          = module.rg.name
  location         = var.location
  vm_name          = var.vm_name
  admin_username   = var.admin_username
  ssh_public_key   = var.ssh_public_key
  nic_id           = module.network.nic_id
  public_ip_dep    = module.network

  depends_on = [module.network]
}
```
</details>

<details> <summary> Root `variables.tf`: </summary>

```bash
variable "location" {
  default = "West Europe"
}

variable "vm_name" {
  default = "week9vm"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key" {}
```
</details>

<details> <summary> Root `outputs.tf`: </summary>

```bash
# Resource Group Outputs
output "rg_name" {
  value = module.rg.name
}

output "rg_location" {
  value = module.rg.location
}

output "rg_id" {
  value = module.rg.id
}

# Network Outputs
output "nic_id" {
  value = module.network.nic_id
}

output "public_ip_address" {
  value = module.network.public_ip
}
```
</details>

<details> <summary>  `modules/resource_group/main.tf` </summary>
```bash
resource "azurerm_resource_group" "devops_rg" {
  name     = var.name
  location = var.location
}
```
</details>

<details> <summary>  `modules/resource_group/variables.tf` </summary>

```bash
variable "name" {}
variable "location" {}
```
</details>

<details> <summary> `modules/resource_group/outputs.tf` </summary>

```bash
output "name" {
  value = azurerm_resource_group.devops_rg.name
}

output "location" {
  value = azurerm_resource_group.devops_rg.location
}

output "id" {
  value = azurerm_resource_group.devops_rg.id
}
```
</details>

<details> <summary> `modules/network/main.tf` </summary>

```bash
resource "azurerm_virtual_network" "vnet" {
  name                = "week9-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_subnet" "subnet" {
  name                 = "week9-subnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "week9-nsg"
  location            = var.location
  resource_group_name = var.rg_name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Backend"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Frontend"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "week9-pip"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "nic" {
  name                = "week9-nic"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
```
</details>

<details> <summary>  `modules/network/variables.tf` </summary>

```bash
variable "location" {}
variable "rg_name" {}
```
</details>

<details> <summary>  `modules/network/outputs.tf` </summary>

```bash
output "nic_id" {
  value = azurerm_network_interface.nic.id
}

output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}
```
</details>

<details> <summary>  `modules/vm/main.tf` </summary>

```bash
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.vm_name
  resource_group_name   = var.rg_name
  location              = var.location
  size                  = "Standard_B1ls"
  admin_username        = var.admin_username
  network_interface_ids = [var.nic_id]

  depends_on = [var.public_ip_dep]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "dev"
  }

  custom_data = filebase64("${path.module}/cloud-init.sh")
}
```
</details>

<details> <summary>  `modules/vm/variables.tf` </summary>

```bash
variable "vm_name" {}
variable "location" {}
variable "rg_name" {}
variable "admin_username" {}
variable "ssh_public_key" {}
variable "nic_id" {}
variable "public_ip_dep" {}
```
</details>

<details> <summary>  `modules/vm/cloud-init.sh` </summary>
to initialize the vm with docker and docker-compose

```bash
#!/bin/bash
# Update package list
apt-get update -y

# Install Docker
apt-get install -y docker.io

# Enable Docker
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

</details>


---

## Configure Remote State
### Create Storage Account & Blob Container
```bash
name: Setup Terraform Remote State Storage

on:
  workflow_call:
    inputs:
      storage-account-name:
        required: true
        type: string
      container-name:
        required: true
        type: string
      key:
        required: false
        default: terraform.tfstate
        type: string
      location:
        required: false
        default: westeurope
        type: string
    secrets:
      AZURE_CREDENTIALS:
        required: true

permissions:
  contents: write # required to commit backend.tf

jobs:
  setup-remote-state:
    name: Configure Azure Storage Backend
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set Resource Group Name
        id: vars
        run: echo "BACKEND_RG=tfstate-backend-rg" >> "$GITHUB_ENV"

      - name: Create Resource Group (for backend only)
        run: |
          az group create \
            --name "$BACKEND_RG" \
            --location "${{ inputs.location }}"

      - name: Create Storage Account (for backend state)
        run: |
          az storage account create \
            --name "${{ inputs.storage-account-name }}" \
            --resource-group "$BACKEND_RG" \
            --location "${{ inputs.location }}" \
            --sku Standard_LRS

      - name: Get Storage Account Key
        id: get-key
        run: |
          ACCOUNT_KEY=$(az storage account keys list \
            --resource-group "$BACKEND_RG" \
            --account-name "${{ inputs.storage-account-name }}" \
            --query '[0].value' -o tsv)
          echo "key=$ACCOUNT_KEY" >> "$GITHUB_OUTPUT"

      - name: Create Blob Container
        run: |
          az storage container create \
            --name "${{ inputs.container-name }}" \
            --account-name "${{ inputs.storage-account-name }}" \
            --account-key "${{ steps.get-key.outputs.key }}" || true

      - name: Generate backend.tf
        run: |
          cat <<EOF > backend.tf
          terraform {
            backend "azurerm" {
              resource_group_name  = "tfstate-backend-rg"
              storage_account_name = "${{ inputs.storage-account-name }}"
              container_name       = "${{ inputs.container-name }}"
              key                  = "${{ inputs.key }}"
            }
          }
          EOF

      - name: Commit and Push backend.tf
        run: |
          git config --global user.name "gh-actions"
          git config --global user.email "github-actions@users.noreply.github.com"
          git add backend.tf
          git commit -m "Add backend.tf for remote state [skip ci]" || echo "No changes to commit"

          BRANCH_NAME=$(echo "${GITHUB_REF#refs/heads/}")
          if [[ "$GITHUB_REF" == refs/heads/* ]]; then
            git push origin HEAD:$GITHUB_REF
          else
            echo "Skipping push — not on a branch."
          fi
```
- which also creates `backend.tf` file based on the created Storage Account

---

## Apply Infrastructure
Apply infrastructure from main `CICD.yml`:
```yml
  deploy-infrastructure:
    needs: setup-remote-state
    uses: ./.github/workflows/terraform-deploy.yml
    with:
      storage-account-name: ${{ needs.setup-remote-state.outputs.storage_account_name }}
    secrets: inherit
```

which calls  
<details> <summary> `terraform-deploy.yml`: </summary>

```yml
  name: Terraform Azure Deployment

  on:
    workflow_call:
      inputs:
        storage-account-name:
          required: true
          type: string
      secrets:
        AZURE_CREDENTIALS:
          required: true
        VM_SSH_KEY:
          required: true

  jobs:
    deploy:
      name: Provision Azure Infrastructure with Terraform
      runs-on: ubuntu-latest

      steps:
        - name: Checkout Repository with latest commit
          uses: actions/checkout@v3
          with:
            fetch-depth: 0

        - name: Azure Login
          uses: azure/login@v1
          with:
            creds: ${{ secrets.AZURE_CREDENTIALS }}

        - name: Set up Terraform
          uses: hashicorp/setup-terraform@v3
          with:
            terraform_version: 1.8.5

        - name: Write SSH Private Key
          run: |
            mkdir -p ~/.ssh
            echo "${{ secrets.VM_SSH_KEY }}" > ~/.ssh/id_rsa
            chmod 600 ~/.ssh/id_rsa

        - name: Derive SSH Public Key
          id: ssh
          run: |
            ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
            echo "ssh_public_key=$(cat ~/.ssh/id_rsa.pub)" >> "$GITHUB_OUTPUT"

        - name: Set Terraform Azure credentials
          run: |
            echo '${{ secrets.AZURE_CREDENTIALS }}' > sp.json
            echo "ARM_CLIENT_ID=$(jq -r .clientId sp.json)" >> $GITHUB_ENV
            echo "ARM_CLIENT_SECRET=$(jq -r .clientSecret sp.json)" >> $GITHUB_ENV
            echo "ARM_SUBSCRIPTION_ID=$(jq -r .subscriptionId sp.json)" >> $GITHUB_ENV
            echo "ARM_TENANT_ID=$(jq -r .tenantId sp.json)" >> $GITHUB_ENV

        - name: Terraform Init
          run: terraform init

        - name: Conditionally Import Resource Group if Not Already in State
          run: |
            RG_NAME="devops-week9-rg"
            SUB_ID="${{ env.ARM_SUBSCRIPTION_ID }}"

            if terraform state list | grep -q "module.rg.azurerm_resource_group.devops_rg"; then
              echo "Resource group already managed in Terraform state. Skipping import."
            else
              EXISTS=$(az group exists --name "$RG_NAME")
              if [ "$EXISTS" == "true" ]; then
                echo "Resource group exists. Importing into Terraform state..."
                terraform import -lock=false module.rg.azurerm_resource_group.devops_rg "/subscriptions/$SUB_ID/resourceGroups/$RG_NAME"
              else
                echo "Resource group does not exist. Terraform will create it during apply."
              fi
            fi

        - name: Terraform Apply
          run: |
            terraform apply -auto-approve \
              -var="ssh_public_key=${{ steps.ssh.outputs.ssh_public_key }}"

        - name: Output Public IP
          run: terraform output public_ip_address
```

What each case means in the `Conditionally Import Resource Group if Not Already in State` step:  
1. if Terraform state contains the RG already
- It skips import and proceeds to terraform apply.

2. if Terraform state does not contain the RG, but it exists in Azure
- It runs terraform import to avoid duplicate resource error during apply.

3. if Terraform state does not contain the RG, and it doesn’t exist in Azure
- No import needed — Terraform will create it during apply.

</details>


### Screenshot of `terraform apply` success :  
![alt text](images/terraform-apply-outputs.png)

## Automatic Deployment and Healthcheck Script

<details> <summary> deploy-webapp.yml </summary>

```yml
name: Deploy WebApp to Azure VM

on:
  workflow_call:
    inputs:
      vm_ip:
        required: true
        type: string
    secrets:
      VM_SSH_KEY:
        required: true

jobs:
  deploy-vm:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Write SSH key
        run: |
          echo "${{ secrets.VM_SSH_KEY }}" > key.pem
          chmod 600 key.pem

      - name: Copy files to VM with rsync
        run: |
          rsync -az --delete --exclude='.git' --exclude='node_modules' -e "ssh -i key.pem -o StrictHostKeyChecking=no" ./ azureuser@${{ inputs.vm_ip }}:/home/azureuser/week9project

      - name: Deploy with docker-compose
        run: |
          ssh -i key.pem -o StrictHostKeyChecking=no azureuser@${{ inputs.vm_ip }} "
            cd /home/azureuser/week9project &&
            sudo docker-compose down --remove-orphans &&
            sudo docker-compose up -d --build
          "

      - name: Healthcheck and get logs
        run: |
          ssh -i key.pem -o StrictHostKeyChecking=no azureuser@${{ inputs.vm_ip }} "
            sudo docker ps
          " > remote_logs.txt

      - name: Upload VM logs
        uses: actions/upload-artifact@v4
        with:
          name: remote-logs
          path: remote_logs.txt

      - name: Cleanup key
        run: rm key.pem
```
</details>

<details> <summary> healthcheck.yml </summary>

```yml
name: healthcheck

on:
  workflow_call:
    outputs:
      ip_status:
        description: "Was the IP made static successfully?"
        value: ${{ jobs.healthcheck.outputs.ip_status }}

jobs:
  healthcheck:
    runs-on: ubuntu-latest
    outputs:
      ip_status: ${{ steps.recheck.outcome }}

    steps:
      - name: Checkout Repo
        uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Get Public IP Name
        id: get_ip_name
        run: |
          IP_NAME=$(az network public-ip list \
            --resource-group devops-week9-rg \
            --query "[0].name" -o tsv)
          echo "IP_NAME=$IP_NAME" >> $GITHUB_ENV

      - name: Make IP Static
        run: |
          az network public-ip update \
            --resource-group devops-week9-rg \
            --name "$IP_NAME" \
            --allocation-method Static

      - name: Get VM Public IP
        id: get_vm_ip
        run: |
          VM_IP=$(az vm show -d -g devops-week9-rg -n week9vm --query publicIps -o tsv)
          echo "VM_IP=$VM_IP" >> $GITHUB_ENV

      - name: Run Initial Healthcheck
        run: |
          echo "Checking http://$VM_IP:3000..." > healthcheck.log
          if curl --fail --silent http://$VM_IP:3000; then
            echo "Initial health check passed" >> healthcheck.log
          else
            echo "Initial health check failed" >> healthcheck.log
            exit 1
          fi
```
</details>

---

## Logging and Documentation
all steps are logged and documented in this file: `deployment_log.md`  
which is being updated automatically after every github Action.

with this step:
```yml
  write-deployment-log:
    needs: post-deploy-week8
    uses: ./.github/workflows/write-deployment-log.yml
    secrets: inherit
```

<details> <summary>`write-deployment-log.yml` </summary>

```yml
name: Write Deployment Log

on:
  workflow_dispatch:
  workflow_call:

permissions:
  contents: write # need this to be able to 'push' to the repo (to update the log file)

jobs:
  log:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Get VM Info (IP, Region, Size, Image)
        id: vm_info
        run: |
          VM_JSON=$(az vm show -g devops-week9-rg -n week9vm)
          echo "VM_IP=$(echo $VM_JSON | jq -r '.publicIps')" >> $GITHUB_ENV
          echo "VM_LOCATION=$(echo $VM_JSON | jq -r '.location')" >> $GITHUB_ENV
          echo "VM_SIZE=$(echo $VM_JSON | jq -r '.hardwareProfile.vmSize')" >> $GITHUB_ENV
          echo "VM_IMAGE=$(echo $VM_JSON | jq -r '.storageProfile.imageReference.offer') $(echo $VM_JSON | jq -r '.storageProfile.imageReference.sku')" >> $GITHUB_ENV

      - name: Create and Append deployment_log.md
        run: |
          TIMESTAMP=$(TZ="Etc/GMT-3" date +"%Y-%m-%d %H:%M:%S")

          echo "Appending new deployment log entry..."

          cat <<EOF >> deployment_log.md

          ---

          ## Deployment Entry - $TIMESTAMP

          **Public IP:** $VM_IP  
          **Region:** $VM_LOCATION  
          **VM Size:** $VM_SIZE  
          **Image:** $VM_IMAGE

          ### Azure CLI Commands Used
          - az login --use-device-code
          - az group create --name devops-week9-rg --location $VM_LOCATION
          - az vm create --resource-group devops-week9-rg --name week9vm --image $VM_IMAGE --size $VM_SIZE ...
          - az network public-ip update --allocation-method Static
          - az vm open-port --port 22 ...
          - scp ./ to VM
          - docker-compose up -d

          ### Deployment Method
          - GitHub Actions CI/CD (via deploy-vm.yml)

          ### Healthcheck
          - curl http://$VM_IP:3000

          ### Reboot Test
          - App recovered after reboot

          ### Browser Compatibility
          - Chrome
          - Firefox
          - Mobile
          EOF

      - name: Commit and push updated deployment_log.md
        run: |
          git config --global user.name "gh-actions"
          git config --global user.email "github-actions@users.noreply.github.com"
          git add deployment_log.md
          git commit -m "Update deployment_log.md [skip ci]" || echo "No changes to commit"

          BRANCH_NAME=$(echo "${GITHUB_REF#refs/heads/}")
          if [[ "$GITHUB_REF" == refs/heads/* ]]; then
            echo "Pushing to branch $BRANCH_NAME..."
            git push origin HEAD:$GITHUB_REF
          else
            echo "Not a branch (probably a tag or detached head), skipping push."
          fi
```
</details>

### example of latest push deployment log :

https://github.com/Benny902/week9summary/blob/main/deployment_log.md

![alt text](images/deployment-log.png)



---

## Resilience Test
This workflow reboots the VM via SSH, waits, then checks if the app is reachable via curl
reboot-check.yml, it is not run automaticaly in the cicd, it can be run individualy in the github actions:

<details> <summary> reboot-check.yml </summary>

```yml
name: Reboot and Healthcheck

on:
  workflow_dispatch:

jobs:
  get-vm-ip:
    uses: ./.github/workflows/get-ip.yml
    secrets: inherit

  reboot-test:
    needs: get-vm-ip
    runs-on: ubuntu-latest

    steps:
      - name: Write SSH key
        run: |
          echo "${{ secrets.VM_SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Reboot VM via SSH
        run: |
          ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa azureuser@${{ needs.get-vm-ip.outputs.vm_ip }} "sudo reboot" || true
          echo "Waiting 90s for reboot..."
          sleep 90

      - name: Health Check After Reboot
        run: |
          echo "Rechecking app at http://${{ needs.get-vm-ip.outputs.vm_ip }}:3000" > reboot-healthcheck.log
          if curl --fail --silent http://${{ needs.get-vm-ip.outputs.vm_ip }}:3000; then
            echo "App came back online" >> reboot-healthcheck.log
          else
            echo "App failed after reboot" >> reboot-healthcheck.log
            exit 1
          fi

      - name: Upload Healthcheck Result
        uses: actions/upload-artifact@v4
        with:
          name: reboot-healthcheck-log
          path: reboot-healthcheck.log
```
</details>

<br>

Reboot check: https://github.com/Benny902/week9summary/actions/runs/16027810765  
![alt text](images/reboot-vm.png)

<br>

Before and after VM reboot:

![alt text](images/before-after.png)

---

## User Experience and Validation

http://20.224.96.1:4000/

</details>
<br>


with the addition Objective of week 10 summary task:
## Objective
Individually build and deploy a simple web application using the full DevOps stack covered
in the course:
- Docker & Docker Compose
- Azure VM infrastructure
- GitHub Actions CI/CD
- Terraform provisioning
- Environment configuration & automation

---


# Week 10:

## Flowchart
![alt text](drawio/week10sum.png)

### GitHubSecrets Required (Settings > Secrets and variables > Actions): 
- VM_SSH_KEY → Contents of the private ~/.ssh/id_rsa file (not the .pub!)
- AZURE_CREDENTIALS → A service principal in JSON format to allow azure/login

<br>

Create `VM_SSH_KEY` with:
```bash
ssh-keygen -t rsa -b 2048
```
- copy the Contents of the private ~/.ssh/id_rsa file (not the .pub!) into the `VM_SSH_KEY` secret

<br>

Create `AZURE_CREDENTIALS` with:
```bash
# to login:
az login --use-device-code

# to see list of accounts associated and verify which is set as default.
az account list --output table

# then create with this: (replaced <SubscriptionId> with mine)
az ad sp create-for-rbac \
  --name "gh-actions" \
  --role contributor \
  --scopes "/subscriptions/<SubscriptionId>" \
  --sdk-auth
```
- copy the entire json output into the `AZURE_CREDENTIALS` secret

---

## Configure Terraform
### Make Modular main.tf and Define Infrastructure Resources

#### Modular folder structure for modules  

```css
root/
├── env/
│   └── dev.env
│   └── prod.env
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/
    ├── resource_group/
    │   └── main.tf
    │   └── variables.tf
    │   └── outputs.tf
    ├── network/
    │   └── main.tf
    │   └── variables.tf
    │   └── outputs.tf
    └── vm/
        └── main.tf
        └── variables.tf
        └── cloud-init.sh
```

# Environment Separation with Terraform
 Folder-Based /env/ Isolation with two env files:  
 `dev.env`:
 ```bash
 rg_name=dev-devops-week10-rg
 ```
`prod.env`:
 ```bash
 rg_name=prod-devops-week10-rg
 ```

 -this is just basic example of difference that can be applied via these files, and here is the result in the azure after deploying with each env:  
 ![alt text](images/week10-states1.png)

 and this is inside the 'tfstate-backend-rg':  
  ![alt text](images/week10-states2.png)


<details> <summary> Root `main.tf`: </summary>

```bash
provider "azurerm" {
  features {}
}

module "rg" {
  source   = "./modules/resource_group"
  name     = "devops-week9-rg"
  location = var.location
}

module "network" {
  source  = "./modules/network"
  rg_name = module.rg.name
  location = var.location
}

module "vm" {
  source           = "./modules/vm"
  rg_name          = module.rg.name
  location         = var.location
  vm_name          = var.vm_name
  admin_username   = var.admin_username
  ssh_public_key   = var.ssh_public_key
  nic_id           = module.network.nic_id
  public_ip_dep    = module.network

  depends_on = [module.network]
}
```
</details>

<details> <summary> Root `variables.tf`: </summary>

```bash
variable "location" {
  default = "West Europe"
}

variable "vm_name" {
  default = "week9vm"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key" {}
```
</details>

<details> <summary> Root `outputs.tf`: </summary>

```bash
# Resource Group Outputs
output "rg_name" {
  value = module.rg.name
}

output "rg_location" {
  value = module.rg.location
}

output "rg_id" {
  value = module.rg.id
}

# Network Outputs
output "nic_id" {
  value = module.network.nic_id
}

output "public_ip_address" {
  value = module.network.public_ip
}
```
</details>

<details> <summary>  `modules/resource_group/main.tf` </summary>
```bash
resource "azurerm_resource_group" "devops_rg" {
  name     = var.name
  location = var.location
}
```
</details>

<details> <summary>  `modules/resource_group/variables.tf` </summary>

```bash
variable "name" {}
variable "location" {}
```
</details>

<details> <summary> `modules/resource_group/outputs.tf` </summary>

```bash
output "name" {
  value = azurerm_resource_group.devops_rg.name
}

output "location" {
  value = azurerm_resource_group.devops_rg.location
}

output "id" {
  value = azurerm_resource_group.devops_rg.id
}
```
</details>

<details> <summary> `modules/network/main.tf` </summary>

```bash
resource "azurerm_virtual_network" "vnet" {
  name                = "week9-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_subnet" "subnet" {
  name                 = "week9-subnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "week9-nsg"
  location            = var.location
  resource_group_name = var.rg_name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Backend"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Frontend"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "week9-pip"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "nic" {
  name                = "week9-nic"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
```
</details>

<details> <summary>  `modules/network/variables.tf` </summary>

```bash
variable "location" {}
variable "rg_name" {}
```
</details>

<details> <summary>  `modules/network/outputs.tf` </summary>

```bash
output "nic_id" {
  value = azurerm_network_interface.nic.id
}

output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}
```
</details>

<details> <summary>  `modules/vm/main.tf` </summary>

```bash
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.vm_name
  resource_group_name   = var.rg_name
  location              = var.location
  size                  = "Standard_B1ls"
  admin_username        = var.admin_username
  network_interface_ids = [var.nic_id]

  depends_on = [var.public_ip_dep]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "dev"
  }

  custom_data = filebase64("${path.module}/cloud-init.sh")
}
```
</details>

<details> <summary>  `modules/vm/variables.tf` </summary>

```bash
variable "vm_name" {}
variable "location" {}
variable "rg_name" {}
variable "admin_username" {}
variable "ssh_public_key" {}
variable "nic_id" {}
variable "public_ip_dep" {}
```
</details>

<details> <summary>  `modules/vm/cloud-init.sh` </summary>
to initialize the vm with docker and docker-compose

```bash
#!/bin/bash
# Update package list
apt-get update -y

# Install Docker
apt-get install -y docker.io

# Enable Docker
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

</details>


---

# Deploying to Dev (triggered on push to main and also can be manualy triggered with workflow_dispatch):

### After the Terraform Plan, there is a need to 'review and approve' before continuing with the 'terraform apply'

Example run:
https://github.com/Benny902/week10summary/actions/runs/16146079121

### before the approve:
![alt text](images/week10-applyapprove1.png)
### the approve:
![alt text](images/week10-applyapprove2.png)
### after the approve:
![alt text](images/week10-applyapprove3.png)


# Deploying to Prod (can Only be manualy triggered with workflow_dispatch):
### The deploy to Prod also has the 'review and approve' between the terraform plan and apply
### And in addition, it has an initial approve gateway in the start of the entire action. 


Example run:
https://github.com/Benny902/week10summary/actions/runs/16146079121

### dropdown to choose environment to deploy:
![alt text](images/week10-gateway1.png)
### before the approve:
![alt text](images/week10-gateway2.png)
### the approve:
![alt text](images/week10-gateway3.png)

### and then it starts with the prod deploy, and afterwards also has the 'review and approve' step between the terraform plan and apply.  


# The CI/CD Pipeline Deploy steps:
main file `cicd.yml`:
```yml
name: Microblog CICD

on:
  push:
    branches:
      - main
    tags:
      - 'v*.*.*'

  workflow_dispatch:
    inputs:
      environment:
        description: 'Choose the environment to deploy'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - prod

permissions:
  contents: write # needed for 'write-deployment-log'

jobs:
  set-environment:
    runs-on: ubuntu-latest
    outputs:
      selected_env: ${{ steps.setenv.outputs.env }}
    steps:
      - name: Determine selected environment
        id: setenv
        run: |
          if [ -z "${{ github.event.inputs.environment }}" ]; then
            echo "env=dev" >> "$GITHUB_OUTPUT"
          else
            echo "env=${{ github.event.inputs.environment }}" >> "$GITHUB_OUTPUT"
          fi

  backend-test:
    needs: set-environment
    uses: ./.github/workflows/backend-test.yml

  frontend-test:
    needs: set-environment
    uses: ./.github/workflows/frontend-test.yml

  gate-approval:
    if: ${{ needs.set-environment.outputs.selected_env == 'prod' }}
    needs: set-environment
    runs-on: ubuntu-latest
    environment:
      name: prod
    outputs:
      approved_env: ${{ needs.set-environment.outputs.selected_env }}
    steps:
      - name: Await manual approval for prod
        run: echo "Approval granted for prod deployment"

  setup-remote-state:
    needs: [backend-test, frontend-test, set-environment, gate-approval]
    if: ${{ needs.set-environment.outputs.selected_env == 'dev' || (needs.set-environment.outputs.selected_env == 'prod' && needs.gate-approval.result == 'success') }}
    uses: ./.github/workflows/setup-remote-state.yml
    with:
      storage-account-name: tfstateweek10infra
      container-name: tfstate
      location: westeurope
      environment: ${{ needs.set-environment.outputs.selected_env }}
    secrets: inherit

  deploy-infrastructure:
    needs: [setup-remote-state, set-environment]
    if: ${{ needs.setup-remote-state.result == 'success' }}
    uses: ./.github/workflows/terraform-deploy.yml
    with:
      storage-account-name: ${{ needs.setup-remote-state.outputs.storage_account_name }}
      key: ${{ needs.setup-remote-state.outputs.tfstate_key }}
      environment: ${{ needs.set-environment.outputs.selected_env }}
    secrets: inherit

  create-and-attach-disk:
    needs: deploy-infrastructure
    uses: ./.github/workflows/create-disk.yml
    secrets: inherit

  get-vm-ip:
    needs: deploy-infrastructure
    uses: ./.github/workflows/get-ip.yml
    secrets: inherit

  deploy-webapp:
    needs: get-vm-ip
    uses: ./.github/workflows/deploy-webapp.yml
    with:
      vm_ip: ${{ needs.get-vm-ip.outputs.vm_ip }}
    secrets: inherit

  healthcheck:
    needs: deploy-webapp
    uses: ./.github/workflows/healthcheck.yml
    secrets: inherit

  backend-notify:
    needs: [backend-test, set-environment, healthcheck]
    if: always()
    uses: ./.github/workflows/notify-backend.yml
    with:
      job_start_time: ${{ needs.backend-test.outputs.job_start_time }}
      test_status: ${{ needs.backend-test.result }}
      build_status: ${{ needs.backend-docker-build.result }}
    secrets: inherit

  frontend-notify:
    needs: [frontend-test, set-environment, healthcheck]
    if: always()
    uses: ./.github/workflows/notify-frontend.yml
    with:
      job_start_time: ${{ needs.frontend-test.outputs.job_start_time }}
      test_status: ${{ needs.frontend-test.result }}
      build_status: ${{ needs.frontend-docker-build.result }}
    secrets: inherit

  e2e-tests:
    needs: deploy-webapp
    uses: ./.github/workflows/e2e-tests.yml

  write-deployment-log:
    needs: healthcheck
    uses: ./.github/workflows/write-deployment-log.yml
    secrets: inherit
```

---

## Configure Remote State
### Create Storage Account & Blob Container
```yml
name: Setup Terraform Remote State Storage

on:
  workflow_call:
    inputs:
      storage-account-name:
        required: true
        type: string
      container-name:
        required: true
        type: string
      key:
        required: false
        default: terraform.tfstate
        type: string
      location:
        required: false
        default: westeurope
        type: string
      environment:
        required: true
        type: string
    outputs:
      storage_account_name:
        description: "Storage account name"
        value: ${{ inputs.storage-account-name }}
      tfstate_key:
        description: "Terraform state key"
        value: ${{ inputs.environment }}.tfstate
    secrets:
      AZURE_CREDENTIALS:
        required: true

permissions:
  contents: write # required to commit backend.tf

jobs:
  setup-remote-state:
    name: Configure Azure Storage Backend
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set Backend Key
        run: echo "TFSTATE_KEY=${{ inputs.environment }}.tfstate" >> $GITHUB_ENV

      - name: Set Resource Group Name
        run: echo "BACKEND_RG=tfstate-backend-rg" >> $GITHUB_ENV

      - name: Create Resource Group (for backend only)
        run: |
          az group create \
            --name "$BACKEND_RG" \
            --location "${{ inputs.location }}"

      - name: Create Storage Account (for backend state)
        run: |
          az storage account create \
            --name "${{ inputs.storage-account-name }}" \
            --resource-group "$BACKEND_RG" \
            --location "${{ inputs.location }}" \
            --sku Standard_LRS

      - name: Get Storage Account Key
        id: get-key
        run: |
          ACCOUNT_KEY=$(az storage account keys list \
            --resource-group "$BACKEND_RG" \
            --account-name "${{ inputs.storage-account-name }}" \
            --query '[0].value' -o tsv)
          echo "key=$ACCOUNT_KEY" >> "$GITHUB_OUTPUT"

      - name: Create Blob Container
        run: |
          az storage container create \
            --name "${{ inputs.container-name }}" \
            --account-name "${{ inputs.storage-account-name }}" \
            --account-key "${{ steps.get-key.outputs.key }}" || true
```

---

## Plan & Apply Infrastructure
```yml
name: Terraform Azure Deployment

on:
  workflow_call:
    inputs:
      storage-account-name:
        required: true
        type: string
      key:
        required: true
        type: string
      environment:
        required: true
        type: string
    secrets:
      AZURE_CREDENTIALS:
        required: true
      VM_SSH_KEY:
        required: true

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    outputs:
      ssh_public_key: ${{ steps.ssh.outputs.ssh_public_key }}
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.8.5

      - name: Write SSH Private Key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.VM_SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Derive SSH Public Key
        id: ssh
        run: |
          ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
          echo "ssh_public_key=$(cat ~/.ssh/id_rsa.pub)" >> "$GITHUB_OUTPUT"

      - name: Set Terraform Azure credentials
        run: |
          echo '${{ secrets.AZURE_CREDENTIALS }}' > sp.json
          echo "ARM_CLIENT_ID=$(jq -r .clientId sp.json)" >> $GITHUB_ENV
          echo "ARM_CLIENT_SECRET=$(jq -r .clientSecret sp.json)" >> $GITHUB_ENV
          echo "ARM_SUBSCRIPTION_ID=$(jq -r .subscriptionId sp.json)" >> $GITHUB_ENV
          echo "ARM_TENANT_ID=$(jq -r .tenantId sp.json)" >> $GITHUB_ENV

      - name: Load Environment Variables
        run: |
          cp "./env/${{ inputs.environment }}.env" .env
          echo "Loaded env/${{ inputs.environment }}.env"
          cat .env >> $GITHUB_ENV

      - name: Debug Storage Account Name
        run: |
          echo "Storage account name: '${{ inputs.storage-account-name }}'"
          echo "Key: '${{ inputs.key }}'"

      - name: Terraform Init
        run: |
          terraform init \
            -backend-config="storage_account_name=${{ inputs.storage-account-name }}" \
            -backend-config="container_name=tfstate" \
            -backend-config="key=${{ inputs.key }}" \
            -backend-config="resource_group_name=tfstate-backend-rg"

      - name: Conditionally Import Resource Group if Not Already in State
        run: |
          RG_NAME="${{ env.rg_name }}"
          SUB_ID="${{ env.ARM_SUBSCRIPTION_ID }}"

          if terraform state list | grep -q "module.rg.azurerm_resource_group.devops_rg"; then
            echo "Resource group already managed in Terraform state. Skipping import."
          else
            EXISTS=$(az group exists --name "$RG_NAME")
            if [ "$EXISTS" == "true" ]; then
              echo "Resource group exists. Importing into Terraform state..."
              terraform import -lock=false module.rg.azurerm_resource_group.devops_rg "/subscriptions/$SUB_ID/resourceGroups/$RG_NAME"
            else
              echo "Resource group does not exist. Terraform will create it during apply."
            fi
          fi

      - name: Terraform Plan
        run: |
          terraform plan \
            -out=tfplan.binary \
            -var="ssh_public_key=${{ steps.ssh.outputs.ssh_public_key }}"
        env:
          TF_VAR_rg_name: ${{ env.rg_name }}

      - name: Upload Terraform Plan Artifact
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: tfplan.binary


  terraform-apply:
    name: Terraform Apply (Manual Approval)
    runs-on: ubuntu-latest
    needs: terraform-plan
    environment:
      name: ${{ inputs.environment }}  # Ensure GitHub UI approval if environment is protected
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.8.5

      - name: Set Terraform Azure credentials
        run: |
          echo '${{ secrets.AZURE_CREDENTIALS }}' > sp.json
          echo "ARM_CLIENT_ID=$(jq -r .clientId sp.json)" >> $GITHUB_ENV
          echo "ARM_CLIENT_SECRET=$(jq -r .clientSecret sp.json)" >> $GITHUB_ENV
          echo "ARM_SUBSCRIPTION_ID=$(jq -r .subscriptionId sp.json)" >> $GITHUB_ENV
          echo "ARM_TENANT_ID=$(jq -r .tenantId sp.json)" >> $GITHUB_ENV

      - name: Load Environment Variables
        run: |
          cp "./env/${{ inputs.environment }}.env" .env
          echo "Loaded env/${{ inputs.environment }}.env"
          cat .env >> $GITHUB_ENV

      - name: Terraform Init
        run: |
          terraform init \
            -backend-config="storage_account_name=${{ inputs.storage-account-name }}" \
            -backend-config="container_name=tfstate" \
            -backend-config="key=${{ inputs.key }}" \
            -backend-config="resource_group_name=tfstate-backend-rg"

      - name: Download Terraform Plan Artifact
        uses: actions/download-artifact@v4
        with:
          name: tfplan

      - name: Terraform Apply
        run: terraform apply tfplan.binary
        env:
          TF_VAR_rg_name: ${{ env.rg_name }}

      - name: Output Public IP
        run: terraform output public_ip_address
```
What each case means in the `Conditionally Import Resource Group if Not Already in State` step:  
1. if Terraform state contains the RG already
- It skips import and proceeds to terraform apply.

2. if Terraform state does not contain the RG, but it exists in Azure
- It runs terraform import to avoid duplicate resource error during apply.

3. if Terraform state does not contain the RG, and it doesn’t exist in Azure
- No import needed — Terraform will create it during apply.

---

## Automatic Deployment

<details> <summary> deploy-webapp.yml </summary>

```yml
name: Deploy WebApp to Azure VM

on:
  workflow_call:
    inputs:
      vm_ip:
        required: true
        type: string
    secrets:
      VM_SSH_KEY:
        required: true

jobs:
  deploy-vm:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Write SSH key
        run: |
          echo "${{ secrets.VM_SSH_KEY }}" > key.pem
          chmod 600 key.pem

      - name: Copy files to VM with rsync
        run: |
          rsync -az --delete --exclude='.git' --exclude='node_modules' -e "ssh -i key.pem -o StrictHostKeyChecking=no" ./ azureuser@${{ inputs.vm_ip }}:/home/azureuser/week9project

      - name: Deploy with docker-compose
        run: |
          ssh -i key.pem -o StrictHostKeyChecking=no azureuser@${{ inputs.vm_ip }} "
            cd /home/azureuser/week9project &&
            sudo docker-compose down --remove-orphans &&
            sudo docker-compose up -d --build
          "

      - name: Healthcheck and get logs
        run: |
          ssh -i key.pem -o StrictHostKeyChecking=no azureuser@${{ inputs.vm_ip }} "
            sudo docker ps
          " > remote_logs.txt

      - name: Upload VM logs
        uses: actions/upload-artifact@v4
        with:
          name: remote-logs
          path: remote_logs.txt

      - name: Cleanup key
        run: rm key.pem
```
</details>

## Healthcheck Script

<details> <summary> healthcheck.yml </summary>

```yml
name: healthcheck

on:
  workflow_call:
    outputs:
      ip_status:
        description: "Was the IP made static successfully?"
        value: ${{ jobs.healthcheck.outputs.ip_status }}
    inputs:
      environment:
        required: true
        type: string
    secrets:
      AZURE_CREDENTIALS:
        required: true

jobs:
  healthcheck:
    runs-on: ubuntu-latest
    outputs:
      ip_status: ${{ steps.recheck.outcome }}

    steps:
      - name: Checkout Repo
        uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set dynamic variables
        run: |
          echo "RESOURCE_GROUP=${{ inputs.environment }}-devops-week10-rg" >> $GITHUB_ENV
          echo "VM_NAME=week10vm" >> $GITHUB_ENV

      - name: Get Public IP Name
        id: get_ip_name
        run: |
          IP_NAME=$(az network public-ip list \
            --resource-group "$RESOURCE_GROUP" \
            --query "[0].name" -o tsv)
          echo "IP_NAME=$IP_NAME" >> $GITHUB_ENV

      - name: Make IP Static
        run: |
          az network public-ip update \
            --resource-group "$RESOURCE_GROUP" \
            --name "$IP_NAME" \
            --allocation-method Static

      - name: Get VM Public IP
        id: get_vm_ip
        run: |
          VM_IP=$(az vm show -d -g "$RESOURCE_GROUP" -n "$VM_NAME" --query publicIps -o tsv)
          echo "VM_IP=$VM_IP" >> $GITHUB_ENV

      - name: Run Initial Healthcheck
        run: |
          echo "Checking http://$VM_IP:3000..." > healthcheck.log
          if curl --fail --silent http://$VM_IP:3000; then
            echo "Initial health check passed" >> healthcheck.log
          else
            echo "Initial health check failed" >> healthcheck.log
            exit 1
          fi
```
</details>

---

## Logging and Documentation
all steps are logged and documented in this file: `deployment_log.md`  
which is being updated automatically after every github Action.

with this step in the main cicd.yml:
```yml
  write-deployment-log:
    needs: healthcheck
    uses: ./.github/workflows/write-deployment-log.yml
    secrets: inherit
```

<details> <summary>`write-deployment-log.yml` </summary>

```yml
name: Write Deployment Log

on:
  workflow_dispatch:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
        
permissions:
  contents: write # need this to be able to 'push' to the repo (to update the log file)

jobs:
  log:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set dynamic variables
        id: vars
        run: |
          echo "RESOURCE_GROUP=${{ inputs.environment }}-devops-week10-rg" >> $GITHUB_ENV
          echo "VM_NAME=week10vm" >> $GITHUB_ENV

      - name: Get VM Info (IP, Region, Size, Image)
        id: vm_info
        run: |
          VM_JSON=$(az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME")
          VM_IP=$(az vm show -d -g "$RESOURCE_GROUP" -n "$VM_NAME" --query publicIps -o tsv)
          echo "VM_IP=$VM_IP" >> $GITHUB_ENV
          echo "VM_LOCATION=$(echo $VM_JSON | jq -r '.location')" >> $GITHUB_ENV
          echo "VM_SIZE=$(echo $VM_JSON | jq -r '.hardwareProfile.vmSize')" >> $GITHUB_ENV
          echo "VM_IMAGE=$(echo $VM_JSON | jq -r '.storageProfile.imageReference.offer') $(echo $VM_JSON | jq -r '.storageProfile.imageReference.sku')" >> $GITHUB_ENV

      - name: Create and Append deployment_log.md
        run: |
          TIMESTAMP=$(TZ="Etc/GMT-3" date +"%Y-%m-%d %H:%M:%S")

          echo "Appending new deployment log entry..."

          cat <<EOF >> deployment_log.md

          ---

          ## Deployment Entry - $TIMESTAMP

          **Environment:** ${{ inputs.environment }}
          **Public IP:** $VM_IP  
          **Region:** $VM_LOCATION  
          **VM Size:** $VM_SIZE  
          **Image:** $VM_IMAGE

          ### Infrastructure
          - Provisioned via **Terraform** (modular setup)
            - Modules: \`resource_group\`, \`network\`, \`vm\`
            - Cloud-init script used for bootstrapping
            - VM auto-runs Docker Compose on startup

          ### Networking
          - Static Public IP assigned
          - NSG Rules configured:
            - Port 22 (SSH)
            - Port 3000 (Backend)
            - Port 4000 (Frontend)

          ### Application Deployment
          - Microblog Backend: http://$VM_IP:3000
          - Microblog Frontend: http://$VM_IP:4000
          - Docker Compose used to deploy both services

          ### Azure CLI Commands Used
          - az login --use-device-code
          - az group create --name $RESOURCE_GROUP --location $VM_LOCATION
          - az network public-ip update --allocation-method Static
          - az vm create ... --image $VM_IMAGE --size $VM_SIZE ...
          - scp ./ to VM
          - docker-compose up -d
          - az network nsg rule create ...

          ### Deployment Method
          - GitHub Actions CI/CD (\`deploy-vm.yml\`)
          - Auto-restart on reboot via cloud-init

          ### Healthcheck
          - curl http://$VM_IP:3000
          - curl http://$VM_IP:4000

          ### Reboot Test
          - App recovered and served frontend/backend correctly

          ### Browser Compatibility
          - Chrome
          - Firefox
          - Mobile

          EOF

      - name: Commit and push updated deployment_log.md
        run: |
          git config --global user.name "gh-actions"
          git config --global user.email "github-actions@users.noreply.github.com"
          git add deployment_log.md
          git commit -m "Update deployment_log.md [skip ci]" || echo "No changes to commit"

          BRANCH_NAME=$(echo "${GITHUB_REF#refs/heads/}")
          if [[ "$GITHUB_REF" == refs/heads/* ]]; then
            echo "Pushing to branch $BRANCH_NAME..."
            git push origin HEAD:$GITHUB_REF
          else
            echo "Not a branch (probably a tag or detached head), skipping push."
          fi
```
</details>

### example of latest push deployment log :

https://github.com/Benny902/week10summary/blob/main/deployment_log.md

![alt text](images/deployment-log.png)



---

## Resilience Test
This workflow reboots the VM via SSH, waits, then checks if the app is reachable via curl
reboot-check.yml, it is not run automaticaly in the cicd, it can be run individualy in the github actions:

<details> <summary> reboot-check.yml </summary>

```yml
name: Reboot and Healthcheck

on:
  workflow_dispatch:

jobs:
  get-vm-ip:
    uses: ./.github/workflows/get-ip.yml
    secrets: inherit

  reboot-test:
    needs: get-vm-ip
    runs-on: ubuntu-latest

    steps:
      - name: Write SSH key
        run: |
          echo "${{ secrets.VM_SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Reboot VM via SSH
        run: |
          ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa azureuser@${{ needs.get-vm-ip.outputs.vm_ip }} "sudo reboot" || true
          echo "Waiting 90s for reboot..."
          sleep 90

      - name: Health Check After Reboot
        run: |
          echo "Rechecking app at http://${{ needs.get-vm-ip.outputs.vm_ip }}:3000" > reboot-healthcheck.log
          if curl --fail --silent http://${{ needs.get-vm-ip.outputs.vm_ip }}:3000; then
            echo "App came back online" >> reboot-healthcheck.log
          else
            echo "App failed after reboot" >> reboot-healthcheck.log
            exit 1
          fi

      - name: Upload Healthcheck Result
        uses: actions/upload-artifact@v4
        with:
          name: reboot-healthcheck-log
          path: reboot-healthcheck.log
```
</details>

<br>

Reboot check:  
![alt text](images/reboot-vm.png)

<br>

Before and after VM reboot:

![alt text](images/before-after.png)

---


#### Project folder structure 

```css
/
├── backend/
├── frontend/
├── docker-compose.yml
├── README.md
├── deployment_log.md
├── env/
│   └── dev.env
│   └── prod.env
├── main.tf
├── variables.tf
├── outputs.tf
├── backend.tf
└── modules/
    ├── resource_group/
    │   └── main.tf
    │   └── variables.tf
    │   └── outputs.tf
    ├── network/
    │   └── main.tf
    │   └── variables.tf
    │   └── outputs.tf
    └── vm/
        └── main.tf
        └── variables.tf
        └── cloud-init.sh
```