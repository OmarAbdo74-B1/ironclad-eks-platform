# On-prem versions (2026-11-19)

## Kubernetes
    Client Version: v1.31.14
    Kustomize Version: v5.4.2
    Server Version: v1.30.14

## Nodes
    NAME           STATUS   ROLES           AGE    VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE          KERNEL-VERSION          CONTAINER-RUNTIME
    controlnode    Ready    control-plane   113d   v1.30.14   10.0.2.1      <none>        CentOS Stream 9   5.14.0-742.el9.x86_64   containerd://2.3.5
    manged-node1   Ready    <none>          113d   v1.30.14   10.0.2.3      <none>        CentOS Stream 9   5.14.0-721.el9.x86_64   containerd://2.2.6
    manged-node2   Ready    <none>          113d   v1.30.14   10.0.2.4      <none>        CentOS Stream 9   5.14.0-721.el9.x86_64   containerd://2.2.6

## Helm releases
    NAME         	NAMESPACE    	REVISION	UPDATED                                 	STATUS  	CHART               	APP VERSION
    argocd       	argocd       	1       	2026-08-22 16:02:56.644700171 +0300 EEST	deployed	argo-cd-10.4.0      	v3.5.1     
    devoooo      	default      	1       	2026-08-21 11:26:16.09694045 +0300 EEST 	deployed	devops-bu-0.1.0     	1.16.0     
    devops       	default      	1       	2026-08-20 18:55:59.674704621 +0300 EEST	deployed	nginx-25.1.1        	1.31.4     
    devops-3     	default      	1       	2026-08-20 19:03:54.314768283 +0300 EEST	deployed	nginx-25.1.1        	1.31.4     
    devops-5     	default      	1       	2026-08-20 19:18:06.631754775 +0300 EEST	deployed	nginx-25.1.1        	1.31.4     
    falco        	falco        	1       	2026-09-21 04:40:54.683352206 +0300 EEST	deployed	falco-9.1.0         	0.44.1     
    ingress-nginx	ingress-nginx	1       	2026-11-15 22:13:11.276621179 +0200 EET 	deployed	ingress-nginx-4.15.1	1.15.1     
    my-release   	default      	1       	2026-08-20 18:37:31.100568792 +0300 EEST	deployed	nginx-25.1.1        	1.31.4     
    traefik      	traefik      	4       	2026-11-18 07:07:07.64514619 +0200 EET  	deployed	traefik-42.4.1      	v3.7.19    

## ArgoCD Helm charts
          chart: kube-prometheus-stack
          targetRevision: 92.21.1
          helm:
    --
          chart: velero
          targetRevision: 12.2.3
          helm:

## Tools server
    CONTAINER           REPOSITORY             TAG                 PLATFORM            IMAGE ID            SIZE                CREATED
    jenkins-pip         tools-server-jenkins   latest              linux/amd64         1b6fc8038a75        1.3GB               2 days ago
    seaweedfs           chrislusf/seaweedfs    4.52                linux/amd64         57877e32bb90        1.06GB              2 weeks ago
    sonar-db            postgres               16-alpine           linux/amd64         81e77a483348        418MB               6 days ago
    sonarqube           sonarqube              community           linux/amd64         65541accbdb9        2.47GB              7 days ago
    trivy-server        aquasec/trivy          0.76.1              linux/amd64         790fd66d1697        262MB               4 weeks ago

## App images
    dev  omarabdo4/butcher-cars-backend:v1.1.3
    dev  omarabdo4/butcher-cars-frontend:v1.1.4
    prod  omarabdo4/butcher-cars-backend:v1.1.3
    prod  omarabdo4/butcher-cars-frontend:v1.1.4
    staging  omarabdo4/butcher-cars-backend:v1.1.3
    staging  omarabdo4/butcher-cars-frontend:v1.1.4
