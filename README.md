# Kubernetes Terraform Provider

The k8s Terraform provider enables Terraform to deploy Kubernetes resources. Unlike the [official Kubernetes provider][kubernetes-provider] it handles raw manifests, leveraging `kubectl` directly to allow developers to work with any Kubernetes resource natively.

This project is a maintained fork of [ericchiang/terraform-provider-k8s](https://github.com/ericchiang/terraform-provider-k8s).

## Installation

### The Go Get way

Use `go get` to install the provider:

```
go get -u github.com/banzaicloud/terraform-provider-k8s
```

Register the plugin in `~/.terraformrc` (see [Documentation](https://www.terraform.io/docs/commands/cli-config.html) for Windows users): 

```hcl
providers {
  k8s = "/$GOPATH/bin/terraform-provider-k8s"
}
```

### The Terraform Plugin way  (enable versioning)

Download a release from the [Release page](https://github.com/banzaicloud/terraform-provider-k8s/releases) and make sure the name matches the following convention:

| OS      | Version | Name                              |
| ------- | ------- | --------------------------------- |
| LINUX   | 0.4.0   | terraform-provider-k8s_v0.4.0     |
|         | 0.3.0   | terraform-provider-k8s_v0.3.0     |
| Windows | 0.4.0   | terraform-provider-k8s_v0.4.0.exe |
|         | 0.3.0   | terraform-provider-k8s_v0.3.0.exe |

Install the plugin using [Terraform Third-party Plugin Documentation](https://www.terraform.io/docs/configuration/providers.html#third-party-plugins):

| Operating system  | User plugins directory        |
| ----------------- | ----------------------------- |
| Windows           | %APPDATA%\terraform.d\plugins |
| All other systems | ~/.terraform.d/plugins        |

## Usage

The provider takes the following optional configuration parameters:

* If you have a kubeconfig available on the file system you can configure the provider as:

```hcl
provider "k8s" {
  kubeconfig = "/path/to/kubeconfig"
}
```

* If you content of the kubeconfig is available in a variable, you can configure the provider as:

```hcl
provider "k8s" {
  kubeconfig_content = "${var.kubeconfig}"
}
```

**WARNING:** Configuration from the variable will be recorded into a temporary file and the file will be removed as
soon as call is completed. This may impact performance if the code runs on a shared system because
and the global tempdir is used.

The k8s Terraform provider introduces a single Terraform resource, a `k8s_manifest`. The resource contains a `content` field, which contains a raw manifest.

```hcl
variable "replicas" {
  type    = "string"
  default = 3
}

data "template_file" "nginx-deployment" {
  template = "${file("manifests/nginx-deployment.yaml")}"

  vars {
    replicas = "${var.replicas}"
  }
}

resource "k8s_manifest" "nginx-deployment" {
  content = "${data.template_file.nginx-deployment.rendered}"
}

# creating a second resource in the nginx namespace
resource "k8s_manifest" "nginx-deployment" {
  content   = "${data.template_file.nginx-deployment.rendered}"
  namespace = "nginx"
}
```

In this case `manifests/nginx-deployment.yaml` is a templated deployment manifest.

```yaml
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```

The Kubernetes resources can then be managed through Terraform.

```terminal
$ terraform apply
# ...
Apply complete! Resources: 1 added, 1 changed, 0 destroyed.
$ kubectl get deployments
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3         3         3            3           1m
$ terraform apply -var 'replicas=5'
# ...
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
$ kubectl get deployments
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   5         5         5            3           3m
$ terraform destroy -force
# ...
Destroy complete! Resources: 2 destroyed.
$ kubectl get deployments
No resources found.
```


## Helm workflow

#### Requirements 

- Helm 2 or Helm 3

Get a versioned chart into your source code and render it

##### Helm 2

``` shell
helm fetch stable/nginx-ingress --version 1.24.4 --untardir charts --untar
helm template --namespace nginx-ingress .\charts\nginx-ingress --output-dir manifests/
```

##### Helm 3

``` shell
helm pull stable/nginx-ingress --version 1.24.4 --untardir charts --untar
helm template --namespace nginx-ingress nginx-ingress .\charts\nginx-ingress --output-dir manifests/
```

Apply the `main.tf` with the k8s provider

```hcl2
# terraform 0.12.x
locals {
  nginx-ingress_files   = fileset(path.module, "manifests/nginx-ingress/templates/*.yaml")
}

data "local_file" "nginx-ingress_files_content" {
  for_each = local.nginx-ingress_files
  filename = each.value
}

resource "k8s_manifest" "nginx-ingress" {
  for_each = data.local_file.nginx-ingress_files_content
  content  = each.value.content
  namespace = "nginx"
}
```

[kubernetes-provider]: https://www.terraform.io/docs/providers/kubernetes/index.html
