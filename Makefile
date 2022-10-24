# Copyright 2022 The k8gb Contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Generated by GoLic, for more details see: https://github.com/AbsaOSS/golic
MAKEAWAY =make -C ../.
MAKEIN =make -C .
I ?=1

deploy-namespaces:
	# create namespaces and ignore if it already exists
	kubectl create namespace demo --dry-run=client -o yaml | kubectl apply --force -f - --context=k3d-test-gslb1
	kubectl create namespace demo --dry-run=client -o yaml | kubectl apply --force -f - --context=k3d-test-gslb2

install-gslbs: deploy-gslbs
deploy-gslbs:
	kubectl -n demo apply -f gslb.yaml --context=k3d-test-gslb1
	kubectl -n demo apply -f gslb.yaml --context=k3d-test-gslb2

deploy-podinfo: deploy-app
deploy-app:
	helm upgrade --install frontend podinfo/podinfo \
		--set ui.message="test-gslb1 (EU Cluster)" \
		--set ui.color="#34577c"\
		--set image.repository=ghcr.io/stefanprodan/podinfo \
		--version 5.1.1 \
		--kube-context k3d-test-gslb2  \
  		--namespace demo

	helm upgrade --install frontend podinfo/podinfo \
		--set ui.message="test-gslb2 (US Cluster)" \
		--set ui.color="#577c34"\
		--set image.repository=ghcr.io/stefanprodan/podinfo \
		--version 5.1.1 \
		--kube-context k3d-test-gslb1 \
		--namespace demo

podinfo-eu: podinfo1
run-app2: podinfo1
podinfo1:
	@echo "CLUSTER1 (EU): Visit http://127.0.0.1:8081"
	kubectl -n demo port-forward deploy/frontend-podinfo 8081:9898 --context=k3d-test-gslb2

podinfo-us: podinfo2
run-app1: podinfo2
podinfo2:
	@echo "CLUSTER2 (US): Visit http://127.0.0.1:8080"
	kubectl -n demo port-forward deploy/frontend-podinfo 8080:9898 --context=k3d-test-gslb1

dig:
	for run in {1..$(I)}; do dig -p 5054 @localhost demo.cloud.example.com +tcp +nostats +noedns +nocomment; done

gslb1:
	kubectl -n demo get gslb gslb --context=k3d-test-gslb1 -oyaml

gslb2:
	kubectl -n demo get gslb gslb --context=k3d-test-gslb2 -oyaml

ep1:
	@echo "EP1 targets" `kubectl get dnsendpoint gslb -oyaml  -n demo --context=k3d-test-gslb1 -o jsonpath={.spec.endpoints[1].targets}`

ep2:
	@echo "EP2 targets" `kubectl get dnsendpoint gslb -oyaml  -n demo --context=k3d-test-gslb2 -o jsonpath={.spec.endpoints[1].targets}`


logs: log
log: stern
stern:
	stern -n k8gb -l app.kubernetes.io/name=coredns  | grep wrr

clear: reset
reset:
	# reset the pod to delete the logs from earlier
	kubectl -n k8gb scale deployment k8gb-coredns --replicas=0 --context=k3d-test-gslb1
	kubectl -n k8gb scale deployment k8gb-coredns --replicas=1 --context=k3d-test-gslb1

	kubectl -n k8gb scale deployment k8gb-coredns --replicas=0 --context=k3d-test-gslb2
	kubectl -n k8gb scale deployment k8gb-coredns --replicas=1 --context=k3d-test-gslb2

	kubectl delete namespace demo --context=k3d-test-gslb1 --ignore-not-found=true
	kubectl delete namespace demo --context=k3d-test-gslb2 --ignore-not-found=true
	kubectl delete namespace test-gslb --context=k3d-test-gslb1 --ignore-not-found=true
	kubectl delete namespace test-gslb --context=k3d-test-gslb2 --ignore-not-found=true
	rm -f ./log.txt 2> /dev/null
	rm -f ./log.log 2> /dev/null
	clear
