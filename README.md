# devops-k3s-assessment
# devops-k3s-assessment
## Environment Setup

### EC2 Instance

Type: t2.micro (1 vCPU, 1 GB RAM)  
OS:Ubuntu 20.04 / 22.04  
Requirements:SSH access, internet connectivity
volume:20gb

# Project overview
This project demonstrates deploying Open WebU on a single-node k3s cluster running on an AWS EC2 instance.  
It includes:

 Docker and k3s setup
 Helm-based application deployment
 OIDC authentication configuration
 Debugging intentional OIDC startup failures

# connect to server using ssh
vi devops.pem
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBlqRUzyu9PU2Y0/IPNnDz4ehQ/wjChjlWXOxV//6wZJgAAAKhJKcn6SSnJ
+gAAAAtzc2gtZWQyNTUxOQAAACBlqRUzyu9PU2Y0/IPNnDz4ehQ/wjChjlWXOxV//6wZJg
AAAEDx4qdK3/UzDwExKyd6/2KaeotGhYy/Jn9iZW/Noo8+QGWpFTPK709TZjT8g82cPPh6
FD/CMKGOVZc7FX//rBkmAAAAIWRlZXBha3BARGVlcGFrcy1NYWNCb29rLVByby5sb2NhbA
ECAwQ=
-----END OPENSSH PRIVATE KEY-----
:wq

chmod 600 devops.pem
ssh -i devops.pem root@46.62.164.72

# install Doocker 
install docker 
sudo apt update -y
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world

# Install k3s (single node cluster)
sudo apt update -y
sudo apt install -y curl
curl -sfL https://get.k3s.io | sh -
sudo systemctl status k3s --no-pager
# setting up kubectl
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown ajithaguru7:$(id -g) $HOME/.kube/config
# verify kubectl
kubectl get nodes
kubectl get pods -A

# Application deployment helm
# install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
# check helm version
helm version
# add repo
helm repo add open-webui https://helm.openwebui.com/
helm repo update
# create namespace
Create ns openwebui
# setup dryrun
helm install webui open-webui/open-webui --namespace openwebui --set service.type=ClusterIP --dry-run
# setup rlease and cluster ip
helm install webui open-webui/webui --namespace openwebui --set service.type=ClusterIP
# Validation:
kubectl get all -n openwebui

# create oidc
vi values-oidc.yaml
oidc:
  clientId: "test"
  clientSecret: ""
  issuer: "https://<YOUR_DOMAIN_HERE>/auth/realms/hyperplane/.well-known/openid-configuration"
  scopes:
	- openid
	- profile
	- email
:wq

helm upgrade webui open-webui/open-webui --namespace openwebui --values values-oidc.yaml
kubectl get all -n openwebui
helm get values webui -n openwebui
------------------------------------------------------------------------------------------------------------------------------------------------------------------
# debugging
invalid issuer
cannot connect to <YOUR_DOMAIN_HERE>
authentication failed

kubectl get pods -n openwebui
kubectl describe pod 
kubectl logs 
Pod status (CrashLoopBackOff, Error, etc.)
Error messages in logs
Environment variables (like clientId, issuer)
# Identify the root cause
The most common reason the app fails after enabling OIDC:
issuer URL is incorrect or placeholder
You likely left <YOUR_DOMAIN_HERE> in the values-oidc.yaml.
The app cannot reach the OIDC provider to authenticate, so it fails on startup.
clientSecret missing (if the provider requires one)
Some OIDC providers need a secret for the app to authenticate.
Network or DNS issues
The pod can’t reach the internet or the identity provider.
How to confirm:
Look at logs: kubectl logs <pod-name> -n openwebui
If you see messages like:	
Replace <YOUR_DOMAIN_HERE> with your actual OIDC issuer URL
Company name.com etc name 

