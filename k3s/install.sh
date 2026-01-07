# k3s/install.sh
Install k3s (single node cluster)
sudo apt update -y sudo apt install -y curl curl -sfL https://get.k3s.io | sh - 
sudo systemctl status k3s --no-pager
#setting up kubectl
mkdir -p $HOME/.kube 
sudo cp /etc/rancher/k3s/k3s.yaml 
sudo chown $(id -u):$(id -g) $HOME/.kube/config
#verify kubectl
kubectl get nodes 
kubectl get pods -A
