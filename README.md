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

# Ownership
Top 5 risks before going live
1.	Misconfigured OIDC authentication
  	If issuer, clientId, or clientSecret are wrong  users cannot log in, app fails.
2.	Pods or services not highly available
  	Only 1 pod deployed single point of failure. If pod crashes, app is down.
3.	No resource limits or monitoring
  	Without CPU/memory limits or monitoring pods could crash under load or consume all cluster resources.
4.	Exposed sensitive secrets
    clientSecret or other credentials not stored securely in plain text in values.yaml security risk.
5.	Network/connectivity issues
    App may fail if it cannot reach the OIDC provider, or if service type (ClusterIP) prevents external access when needed.

First 2 things you would fix before going live
1.	Secure OIDC secrets
  Move clientSecret into a Kubernetes Secret instead of keeping it in values.yaml.
  Update Helm to reference the secret.
	Ensures credentials are not exposed in config files or logs.
2.	High availability  for pods
         Increase replica count in the Deployment (e.g., replicas: 3).
         Optionally configure a LoadBalancer or Ingress for access.
         Ensures app stays up even if one pod fails.
         hpa can also added for auto scaling
  	
# Failure scenario
What breaks first?

Pods may crash or restart due to memory and CPU exhaustion.
WebUI service becomes unresponsive.
Kubernetes control plane may slow down because it’s on the same node.
Logs and monitoring may show OOMKilled events.

How do you recover?
Restart failing pods:
kubectl get pods -n openwebui
kubectl delete pod <pod-name> -n openwebui
Temporarily scale down workloads if possible.

Longer-term:
Launch a larger EC2 instance or add a node to the cluster.
Use horizontal pod autoscaling (HPA) for WebUI.
Enable monitoring to detect spikes early.

What to change the next day?

Cluster sizing: Upgrade from t2.micro to t2.medium or multi-node cluster.
Resource limits/requests: Configure CPU/memory for pods.
Autoscaling: Enable HPA for WebUI.
Load testing: Simulate traffic spikes to ensure stability.
Alerting: Set up alerts for high CPU/memory usage.

# Security & Secrets

How do you manage secrets?
Store sensitive values (like clientSecret) in Kubernetes Secrets or environment variables, not in plain files.
Use Helm values files (values-oidc.yaml) but keep them excluded from Git.
Access secrets only via kubectl get secret or mounted as env/config in pods.

What must never be in Git?
Secrets: passwords, API keys, OIDC client secrets.
Any .env files containing credentials.
Any local logs or temporary keys.
Use .gitignore to prevent them from being committed.

What should be rotated?
Client secrets, API keys, tokens — especially if exposed or after a breach.
Certificates (if used for HTTPS or OIDC).
User access credentials regularly to follow best practices.

# backup

What data must be backed up?
Kubernetes manifests (deployments, services, configmaps, secrets)
Persistent data volumes (EBS,PV, PVCs, database files, uploaded files)
Helm values files (values-oidc.yaml) excluding secrets if stored elsewhere

Backup frequency
Critical data (databases, user uploads)daily or more frequent
Manifests / Helm charts / configs  after each change
Automate backups using  AWS snapshots

 How do you test recovery?
Restore backups to a test cluster
Verify that pods, services, and data are functional
Simulate disaster scenarios (node failure, pod crash, data deletion)
Document the recovery procedure for future incidents

# Cost & Ownership (Hetzner)
How to keep infrastructure costs low?
Start with small instances (e.g., t2.micro or Hetzner ) for testing and development.
Use single-node k3s for lightweight clusters.
Automate shutdown of unused servers and remove unnecessary storage.
Use cloud-native services sparingly to avoid extra costs.

 What to avoid early?
High-availability multi-node clusters — unnecessary for early-stage testing.
Expensive managed databases or premium services.
Over-provisioning CPU, memory, or storage.

 When to move away from k3s?
Traffic or resource demands exceed a single node.
Production-grade high availability, load balancing, and security are required.
Need advanced Kubernetes features or scaling beyond lightweight workloads.

# Extra Credit
Make the app trust the custom CA
Obtain the CA certificate
Export the .crt of the self-signed CA from your OIDC provider.
Create a Kubernetes ConfigMap or Secret
Store the CA certificate in a ConfigMap or Secret so it can be mounted into the pod.
kubectl create configmap oidc-ca --from-file=ca.crt -n openwebui


Mount the CA into the application pod
Modify your Helm values or deployment to mount the CA certificate at a standard location (e.g., /usr/local/share/ca-certificates/).
Update the container’s trusted certificates
set environment variable NODE_EXTRA_CA_CERTS=/path/to/ca.crt if using Node.js-based apps.

Maintainability

Keep the CA in a version-controlled ConfigMap/Secret, separate from the application image.
Updates to the CA only require re-deploying the pod without rebuilding the image.

