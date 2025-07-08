
---

## Deployment Entry - 2025-07-08 16:02:09

**Public IP:** 23.97.156.53  
**Region:** westeurope  
**VM Size:** Standard_B1ls  
**Image:** UbuntuServer 18.04-LTS

### Infrastructure
- Provisioned via **Terraform** (modular setup)
  - Modules: , , 
  - Cloud-init script used for bootstrapping
  - VM auto-runs Docker Compose on startup

### Networking
- Static Public IP assigned
- NSG Rules configured:
  - Port 22 (SSH)
  - Port 3000 (Backend)
  - Port 4000 (Frontend)

### Application Deployment
- Microblog Backend: http://23.97.156.53:3000
- Microblog Frontend: http://23.97.156.53:4000
- Docker Compose used to deploy both services

### Azure CLI Commands Used
- az login --use-device-code
- az group create --name dev-devops-week10-rg --location westeurope
- az network public-ip update --allocation-method Static
- az vm create ... --image UbuntuServer 18.04-LTS --size Standard_B1ls ...
- scp ./ to VM
- docker-compose up -d
- az network nsg rule create ...

### Deployment Method
- GitHub Actions CI/CD ()
- Auto-restart on reboot via cloud-init

### Healthcheck
- curl http://23.97.156.53:3000
- curl http://23.97.156.53:4000

### Reboot Test
- App recovered and served frontend/backend correctly

### Browser Compatibility
- Chrome
- Firefox
- Mobile


---

## Deployment Entry - 2025-07-08 17:40:21

**Public IP:** 23.97.156.53  
**Region:** westeurope  
**VM Size:** Standard_B1ls  
**Image:** UbuntuServer 18.04-LTS

### Infrastructure
- Provisioned via **Terraform** (modular setup)
  - Modules: , , 
  - Cloud-init script used for bootstrapping
  - VM auto-runs Docker Compose on startup

### Networking
- Static Public IP assigned
- NSG Rules configured:
  - Port 22 (SSH)
  - Port 3000 (Backend)
  - Port 4000 (Frontend)

### Application Deployment
- Microblog Backend: http://23.97.156.53:3000
- Microblog Frontend: http://23.97.156.53:4000
- Docker Compose used to deploy both services

### Azure CLI Commands Used
- az login --use-device-code
- az group create --name dev-devops-week10-rg --location westeurope
- az network public-ip update --allocation-method Static
- az vm create ... --image UbuntuServer 18.04-LTS --size Standard_B1ls ...
- scp ./ to VM
- docker-compose up -d
- az network nsg rule create ...

### Deployment Method
- GitHub Actions CI/CD ()
- Auto-restart on reboot via cloud-init

### Healthcheck
- curl http://23.97.156.53:3000
- curl http://23.97.156.53:4000

### Reboot Test
- App recovered and served frontend/backend correctly

### Browser Compatibility
- Chrome
- Firefox
- Mobile


---

## Deployment Entry - 2025-07-08 18:09:05

**Public IP:** 23.97.156.53  
**Region:** westeurope  
**VM Size:** Standard_B1ls  
**Image:** UbuntuServer 18.04-LTS

### Infrastructure
- Provisioned via **Terraform** (modular setup)
  - Modules: , , 
  - Cloud-init script used for bootstrapping
  - VM auto-runs Docker Compose on startup

### Networking
- Static Public IP assigned
- NSG Rules configured:
  - Port 22 (SSH)
  - Port 3000 (Backend)
  - Port 4000 (Frontend)

### Application Deployment
- Microblog Backend: http://23.97.156.53:3000
- Microblog Frontend: http://23.97.156.53:4000
- Docker Compose used to deploy both services

### Azure CLI Commands Used
- az login --use-device-code
- az group create --name dev-devops-week10-rg --location westeurope
- az network public-ip update --allocation-method Static
- az vm create ... --image UbuntuServer 18.04-LTS --size Standard_B1ls ...
- scp ./ to VM
- docker-compose up -d
- az network nsg rule create ...

### Deployment Method
- GitHub Actions CI/CD ()
- Auto-restart on reboot via cloud-init

### Healthcheck
- curl http://23.97.156.53:3000
- curl http://23.97.156.53:4000

### Reboot Test
- App recovered and served frontend/backend correctly

### Browser Compatibility
- Chrome
- Firefox
- Mobile

