kube-namespace namespace:
    kubectl create namespace {{namespace}}

kube-role namespace:
    #!/usr/bin/env bash
    export NAMESPACE={{namespace}}
    cat resources/deployment-role.yaml | envsubst | kubectl apply -f -

kube-rolebinding user namespace:
    #!/usr/bin/env bash
    export NAME={{user}}-deployment-manager
    export NAMESPACE={{namespace}}
    export USER={{user}}
    export ROLE=deployment-manager
    cat resources/role-binding.yaml | envsubst | kubectl apply -f -

kube-client-cert user group="admin":
    #!/usr/bin/env bash
    # generate private key
    openssl genrsa -out artifacts/{{user}}.key 2048
    # create certificate signing request
    openssl req -new -key artifacts/{{user}}.key -out artifacts/{{user}}.csr -subj "/CN={{user}}/O={{group}}"
    # submit csr to certificate authority
    export NAME={{user}}
    export REQUEST=$(cat artifacts/{{user}}.csr | base64 | tr -d '\n')
    cat resources/client-csr.yaml | envsubst | kubectl apply -f -
    # approve csr
    kubectl certificate approve {{user}}
 
kube-config cluster namespace user:
    #!/usr/bin/env bash
    export USER={{user}}
    export NAMESPACE={{namespace}}
    export CLUSTER_NAME={{cluster}}
    export CLUSTER_CA=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority-data"')
    export CLUSTER_ENDPOINT=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."server"')
    export CLIENT_CERTIFICATE_DATA=$(kubectl get csr {{user}} -o jsonpath='{.status.certificate}')
    cat resources/config.yaml | envsubst > artifacts/{{user}}-kubeconfig

kube-config-install user:
    cp artifacts/{{user}}-kubeconfig ~/.kube/config
    kubectl config set-credentials {{user}} --client-key=artifacts/{{user}}.key --embed-certs=true

kube-setup cluster namespace user: 
    just kube-namespace {{namespace}}
    just kube-role {{namespace}}
    just kube-rolebinding {{user}} {{namespace}}
    just kube-config {{cluster}} {{namespace}} {{user}}
