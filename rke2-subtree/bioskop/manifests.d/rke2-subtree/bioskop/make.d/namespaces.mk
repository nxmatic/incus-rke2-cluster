# Generated namespace extraction rules

rke2-subtree/bioskop/manifests.d/envoy-gateway-system: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace envoy-gateway-system'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "envoy-gateway-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/envoy-gateway-system/serviceaccount-envoy-gateway-installer.yaml: rke2-subtree/bioskop/manifests.d/envoy-gateway-system
	: 'Extracting serviceaccount-envoy-gateway-installer in namespace envoy-gateway-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "envoy-gateway-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/envoy-gateway-system/job-envoy-gateway-installer.yaml: rke2-subtree/bioskop/manifests.d/envoy-gateway-system
	: 'Extracting job-envoy-gateway-installer in namespace envoy-gateway-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "envoy-gateway-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/flox-runtime: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace flox-runtime'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "flox-runtime")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/flox-runtime/serviceaccount-flox-runtime-installer.yaml: rke2-subtree/bioskop/manifests.d/flox-runtime
	: 'Extracting serviceaccount-flox-runtime-installer in namespace flox-runtime'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "flox-runtime")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/flox-runtime/daemonset-flox-runtime-installer.yaml: rke2-subtree/bioskop/manifests.d/flox-runtime
	: 'Extracting daemonset-flox-runtime-installer in namespace flox-runtime'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "flox-runtime")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace headscale'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/serviceaccount-headscale-bootstrap.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting serviceaccount-headscale-bootstrap in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/serviceaccount-headscale-client.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting serviceaccount-headscale-client in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/serviceaccount-headscale-gateway.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting serviceaccount-headscale-gateway in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/role-headscale-bootstrap.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting role-headscale-bootstrap in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/rolebinding-headscale-bootstrap.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting rolebinding-headscale-bootstrap in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/configmap-headscale-acl.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting configmap-headscale-acl in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/configmap-headscale-config.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting configmap-headscale-config in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/configmap-headscale-derp.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting configmap-headscale-derp in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/service-headscale.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting service-headscale in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/deployment-headscale.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting deployment-headscale in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/deployment-headscale-gateway.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting deployment-headscale-gateway in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/daemonset-headscale-client.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting daemonset-headscale-client in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/headscale/job-headscale-bootstrap.yaml: rke2-subtree/bioskop/manifests.d/headscale
	: 'Extracting job-headscale-bootstrap in namespace headscale'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "headscale")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/kube-vip: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace kube-vip'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "kube-vip")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/kube-vip/serviceaccount-kube-vip.yaml: rke2-subtree/bioskop/manifests.d/kube-vip
	: 'Extracting serviceaccount-kube-vip in namespace kube-vip'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "kube-vip")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/kube-vip/daemonset-kube-vip-ds.yaml: rke2-subtree/bioskop/manifests.d/kube-vip
	: 'Extracting daemonset-kube-vip-ds in namespace kube-vip'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "kube-vip")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/openebs: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace openebs'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "openebs")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/openebs/helmchart-openebs-zfs.yaml: rke2-subtree/bioskop/manifests.d/openebs
	: 'Extracting helmchart-openebs-zfs in namespace openebs'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "openebs")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-fn-system: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace porch-fn-system'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "porch-fn-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-fn-system/serviceaccount-default.yaml: rke2-subtree/bioskop/manifests.d/porch-fn-system
	: 'Extracting serviceaccount-default in namespace porch-fn-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-fn-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-fn-system/role-porch-function-executor.yaml: rke2-subtree/bioskop/manifests.d/porch-fn-system
	: 'Extracting role-porch-function-executor in namespace porch-fn-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-fn-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-fn-system/rolebinding-porch-function-executor.yaml: rke2-subtree/bioskop/manifests.d/porch-fn-system
	: 'Extracting rolebinding-porch-function-executor in namespace porch-fn-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-fn-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace porch-system'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/serviceaccount-porch-controllers.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting serviceaccount-porch-controllers in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/serviceaccount-porch-fn-runner.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting serviceaccount-porch-fn-runner in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/serviceaccount-porch-server.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting serviceaccount-porch-server in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/role-aggregated-apiserver-role.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting role-aggregated-apiserver-role in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/rolebinding-sample-apiserver-rolebinding.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting rolebinding-sample-apiserver-rolebinding in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/configmap-pod-cache-config.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting configmap-pod-cache-config in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/service-api.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting service-api in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/service-function-runner.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting service-function-runner in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/deployment-function-runner.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting deployment-function-runner in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/deployment-porch-controllers.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting deployment-porch-controllers in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/deployment-porch-server.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting deployment-porch-server in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/packagevariant-ha-kube-vip.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting packagevariant-ha-kube-vip in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/packagevariant-mesh-headscale.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting packagevariant-mesh-headscale in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/packagevariant-mesh-tailscale.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting packagevariant-mesh-tailscale in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/packagevariant-networking-cilium.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting packagevariant-networking-cilium in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/packagevariant-networking-envoy-gateway.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting packagevariant-networking-envoy-gateway in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/packagevariant-runtime-flox.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting packagevariant-runtime-flox in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/packagevariant-storage-openebs-zfs.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting packagevariant-storage-openebs-zfs in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/repository-bioskop-catalog.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting repository-bioskop-catalog in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/porch-system/repository-bioskop-state.yaml: rke2-subtree/bioskop/manifests.d/porch-system
	: 'Extracting repository-bioskop-state in namespace porch-system'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "porch-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tailscale-system: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace tailscale-system'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "tailscale-system")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines: rke2-subtree/bioskop/manifests.d/
	: 'Extracting namespace tekton-pipelines'
	mkdir -p $(@)
	cd $(@D)
	yq --split-exp='.metadata.name|downcase' \
		eval-all 'select(.kind == "Namespace" and .apiVersion == "v1" and .metadata.name == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/serviceaccount-tekton-bot.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting serviceaccount-tekton-bot in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/serviceaccount-tekton-events-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting serviceaccount-tekton-events-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/serviceaccount-tekton-pipelines-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting serviceaccount-tekton-pipelines-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/serviceaccount-tekton-pipelines-resolvers.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting serviceaccount-tekton-pipelines-resolvers in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/serviceaccount-tekton-pipelines-webhook.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting serviceaccount-tekton-pipelines-webhook in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/role-tekton-pipelines-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting role-tekton-pipelines-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/role-tekton-pipelines-events-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting role-tekton-pipelines-events-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/role-tekton-pipelines-info.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting role-tekton-pipelines-info in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/role-tekton-pipelines-leader-election.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting role-tekton-pipelines-leader-election in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/role-tekton-pipelines-resolvers-namespace-rbac.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting role-tekton-pipelines-resolvers-namespace-rbac in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/role-tekton-pipelines-webhook.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting role-tekton-pipelines-webhook in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/rolebinding-tekton-events-controller-leaderelection.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting rolebinding-tekton-events-controller-leaderelection in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/rolebinding-tekton-pipelines-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting rolebinding-tekton-pipelines-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/rolebinding-tekton-pipelines-controller-leaderelection.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting rolebinding-tekton-pipelines-controller-leaderelection in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/rolebinding-tekton-pipelines-events-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting rolebinding-tekton-pipelines-events-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/rolebinding-tekton-pipelines-info.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting rolebinding-tekton-pipelines-info in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/rolebinding-tekton-pipelines-resolvers-namespace-rbac.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting rolebinding-tekton-pipelines-resolvers-namespace-rbac in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/rolebinding-tekton-pipelines-webhook.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting rolebinding-tekton-pipelines-webhook in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/rolebinding-tekton-pipelines-webhook-leaderelection.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting rolebinding-tekton-pipelines-webhook-leaderelection in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-bundleresolver-config.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-bundleresolver-config in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-cluster-resolver-config.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-cluster-resolver-config in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-defaults.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-defaults in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-events.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-events in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-leader-election-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-leader-election-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-leader-election-events.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-leader-election-events in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-leader-election-resolvers.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-leader-election-resolvers in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-leader-election-webhook.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-leader-election-webhook in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-logging.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-logging in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-observability.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-observability in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-registry-cert.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-registry-cert in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-spire.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-spire in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-tracing.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-tracing in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-config-wait-exponential-backoff.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-config-wait-exponential-backoff in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-feature-flags.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-feature-flags in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-git-resolver-config.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-git-resolver-config in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-http-resolver-config.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-http-resolver-config in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-hubresolver-config.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-hubresolver-config in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-pipelines-info.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-pipelines-info in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-resolver-cache-config.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-resolver-cache-config in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/configmap-resolvers-feature-flags.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting configmap-resolvers-feature-flags in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/secret-webhook-certs.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting secret-webhook-certs in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/service-tekton-events-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting service-tekton-events-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/service-tekton-pipelines-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting service-tekton-pipelines-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/service-tekton-pipelines-remote-resolvers.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting service-tekton-pipelines-remote-resolvers in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/service-tekton-pipelines-webhook.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting service-tekton-pipelines-webhook in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/deployment-tekton-events-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting deployment-tekton-events-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/deployment-tekton-pipelines-controller.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting deployment-tekton-pipelines-controller in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/deployment-tekton-pipelines-remote-resolvers.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting deployment-tekton-pipelines-remote-resolvers in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/deployment-tekton-pipelines-webhook.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting deployment-tekton-pipelines-webhook in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

rke2-subtree/bioskop/manifests.d/tekton-pipelines/horizontalpodautoscaler-tekton-pipelines-webhook.yaml: rke2-subtree/bioskop/manifests.d/tekton-pipelines
	: 'Extracting horizontalpodautoscaler-tekton-pipelines-webhook in namespace tekton-pipelines'
	cd $(@D)
	yq --split-exp='(.kind|downcase)+"-"+(.metadata.name|downcase)' \
		eval-all 'select(.metadata.namespace == "tekton-pipelines")' \
		rke2-subtree/bioskop/manifests.yaml

