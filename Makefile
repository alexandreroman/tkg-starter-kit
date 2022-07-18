CERT_MANAGER_VERSION=1.4.2
EXTERNAL_DNS_CHART_VERSION=5.4.5
CONTOUR_CHART_VERSION=5.1.0
HARBOR_CHART_VERSION=1.9.3
CONCOURSE_CHART_VERSION=15.7.0
JENKINS_CHART_VERSION=3.5.9
KUBEAPPS_CHART_VERSION=7.3.2
ARTIFACTORY_CHART_VERSION=107.23.3
PROMETHEUS_CHART_VERSION=6.1.4

.PHONY: clean prepare

clean:
	-rm -f _ytt.*.yml infra/aws/k8s.yml infra/aws/values-external-dns.yml

purge: clean
	@cd infra/aws && terraform destroy
	-rm -fr infra/aws/.terraform* infra/aws/terraform.tfstate*

init:
	kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

prepare: deploy-base
	$(shell ytt -f infra/aws/terraform.tfvars.yml -f config -f config-custom >infra/aws/terraform.tfvars)

infra/aws/values-external-dns.yml: infra/aws/values-external-dns.tpl infra/aws/k8s.yml

infra/aws/k8s.yml: infra/aws/k8s.tpl ${wildcard infra/aws/*.tf} infra/aws/terraform.tfvars
	@cd infra/aws && terraform apply -auto-approve

infra/aws/terraform.tfvars:
	$(shell ytt -f infra/aws/terraform.tfvars.yml -f config -f config-custom | sed 's/: /="/g' | sed 's/$$/"/' >infra/aws/terraform.tfvars)
	@cd infra/aws && terraform init

deploy-base: infra/aws/k8s.yml infra/aws/values-external-dns.yml
	$(shell ytt -f infra/aws/values-external-dns.yml -f config -f config-custom >_ytt.0.yml)
	$(shell helm template external-dns https://charts.bitnami.com/bitnami/external-dns-${EXTERNAL_DNS_CHART_VERSION}.tgz -n external-dns -f _ytt.0.yml >_ytt.1.yml)
	$(shell ytt -f infra/aws/k8s.yml -f https://github.com/jetstack/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.yaml -f _ytt.1.yml -f modules/base/fix-external-dns-ns.yml -f modules/base/remove-cert-manager-crds.yml -f config -f config-custom >_ytt.2.yml)
	kapp deploy -y -a sk-base -f _ytt.2.yml
	@-rm -f _ytt.*.yml

deploy-contour: deploy-base
	$(shell helm template contour https://charts.bitnami.com/bitnami/contour-${CONTOUR_CHART_VERSION}.tgz -n contour >_ytt.0.yml)
	$(shell ytt -f _ytt.0.yml -f modules/contour/fix-ns.yml -f config -f config-custom >_ytt.1.yml)
	kapp deploy -y -a sk-contour -f _ytt.1.yml
	@-rm -f _ytt.*.yml

deploy-harbor: deploy-base
	$(shell ytt -f modules/harbor/values-harbor.yml -f config -f config-custom >_ytt.0.yml)
	$(shell helm template harbor https://helm.goharbor.io/harbor-${HARBOR_CHART_VERSION}.tgz -n harbor -f _ytt.0.yml >_ytt.1.yml)
	$(shell ytt -f _ytt.1.yml -f modules/harbor/fix-ns.yml -f config -f config-custom >_ytt.2.yml)
	kapp deploy -y -a sk-harbor -f _ytt.2.yml
	@-rm -f _ytt.*.yml

deploy-concourse: deploy-base
	$(shell ytt -f modules/concourse/values-concourse.yml -f config -f config-custom >_ytt.0.yml)
	$(shell helm template concourse https://concourse-charts.storage.googleapis.com/concourse-${CONCOURSE_CHART_VERSION}.tgz -n concourse -f _ytt.0.yml >_ytt.1.yml)
	$(shell ytt -f _ytt.1.yml -f modules/concourse/fix-ns.yml -f config -f config-custom >_ytt.2.yml)
	kapp deploy -y -a sk-concourse -f _ytt.2.yml
	@-rm -f _ytt.*.yml

deploy-jenkins: deploy-base
	$(shell ytt -f modules/jenkins/values-jenkins.yml -f config -f config-custom >_ytt.0.yml)
	$(shell helm template jenkins https://github.com/jenkinsci/helm-charts/releases/download/jenkins-${JENKINS_CHART_VERSION}/jenkins-${JENKINS_CHART_VERSION}.tgz -n jenkins -f _ytt.0.yml >_ytt.1.yml)
	$(shell ytt -f _ytt.1.yml -f modules/jenkins/fix-ns.yml -f config -f config-custom >_ytt.2.yml)
	kapp deploy -y -a sk-jenkins -f _ytt.2.yml
	@-rm -f _ytt.*.yml

deploy-kubeapps: deploy-base
	$(shell ytt -f modules/kubeapps/values-kubeapps.yml -f config -f config-custom >_ytt.0.yml)
	$(shell helm template kubeapps https://charts.bitnami.com/bitnami/kubeapps-${KUBEAPPS_CHART_VERSION}.tgz -n kubeapps -f _ytt.0.yml >_ytt.1.yml)
	$(shell ytt -f _ytt.1.yml -f modules/kubeapps/fix-ns.yml -f modules/kubeapps/rbac.yml -f modules/kubeapps/app-repos.yml -f https://raw.githubusercontent.com/kubeapps/kubeapps/master/chart/kubeapps/crds/apprepository-crd.yaml -f config -f config-custom >_ytt.2.yml)
	kapp deploy -y -a sk-kubeapps -f _ytt.2.yml
	@-rm -f _ytt.*.yml
	@echo "Run this command to get credentials:"
	@echo "$$ kubectl get secret $$(kubectl get serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' && echo"

deploy-artifactory: deploy-base
	$(shell ytt -f modules/artifactory/values-artifactory.yml -f config -f config-custom >_ytt.0.yml)
	$(shell helm template artifactory https://charts.jfrog.io/artifactory/api/helm/jfrog-charts/artifactory-oss-${ARTIFACTORY_CHART_VERSION}.tgz -n artifactory -f _ytt.0.yml >_ytt.1.yml)
	$(shell ytt -f _ytt.1.yml -f modules/artifactory/fix-ns.yml -f modules/artifactory/master-key.yml -f config -f config-custom >_ytt.2.yml)
	kapp deploy -y -a sk-artifactory -f _ytt.2.yml
	@-rm -f _ytt.*.yml
	@echo "Default credentials: admin / password"

deploy-prometheus: deploy-base
	$(shell ytt -f modules/prometheus/values-prometheus.yml -f config -f config-custom >_ytt.0.yml)
	$(shell helm template prometheus https://charts.bitnami.com/bitnami/kube-prometheus-${PROMETHEUS_CHART_VERSION}.tgz -n prometheus -f _ytt.0.yml >_ytt.1.yml)
	$(shell ytt -f _ytt.1.yml -f modules/prometheus/fix-ns.yml -f modules/prometheus/fix-labels.yml -f https://raw.githubusercontent.com/bitnami/charts/master/bitnami/kube-prometheus/crds/crd-alertmanager-config.yaml -f https://raw.githubusercontent.com/bitnami/charts/master/bitnami/kube-prometheus/crds/crd-alertmanager.yaml -f https://raw.githubusercontent.com/bitnami/charts/master/bitnami/kube-prometheus/crds/crd-podmonitor.yaml -f https://raw.githubusercontent.com/bitnami/charts/master/bitnami/kube-prometheus/crds/crd-probes.yaml -f https://raw.githubusercontent.com/bitnami/charts/master/bitnami/kube-prometheus/crds/crd-prometheus.yaml -f https://raw.githubusercontent.com/bitnami/charts/master/bitnami/kube-prometheus/crds/crd-prometheusrules.yaml -f https://raw.githubusercontent.com/bitnami/charts/master/bitnami/kube-prometheus/crds/crd-servicemonitor.yaml -f config -f config-custom >_ytt.2.yml)
	kapp deploy -y -a sk-prometheus -f _ytt.2.yml
	@-rm -f _ytt.*.yml

deploy-kpack: deploy-base
	kapp deploy -y -a sk-kpack -f modules/kpack/cluster-stack.yml -f modules/kpack/cluster-store.yml -f https://github.com/pivotal/kpack/releases/download/v0.3.1/release-0.3.1.yaml
	@echo ClusterStore and ClusterStack instances have been deployed to your cluster.
	@echo Follow kpack tutorial to set up a ServiceAccount and a ClusterBuilder:
	@echo "  https://github.com/pivotal/kpack/blob/main/docs/tutorial.md"
