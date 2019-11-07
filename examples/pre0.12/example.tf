data "template_file" "my-configmap" {
  template = "${file("${path.module}/../manifests/my-configmap.yaml")}"

  vars {
    greeting = "${var.greeting}"
  }
}

resource "k8s_manifest" "my-configmap" {
  content = "${data.template_file.my-configmap.rendered}"
}

data "template_file" "nginx-deployment" {
  template = "${file("${path.module}/../manifests/nginx-deployment.yaml")}"

  vars {
    replicas = "${var.replicas}"
  }
}

resource "k8s_manifest" "nginx-deployment" {
  content = "${data.template_file.nginx-deployment.rendered}"
}

data "template_file" "nginx-namespace" {
  template = "${file("${path.module}/../manifests/nginx-namespace.yaml")}"
}

resource "k8s_manifest" "nginx-namespace" {
  content   = "${data.template_file.nginx-namespace.rendered}"
  namespace = "kube-system"
}

resource "k8s_manifest" "nginx-deployment-with-namespace" {
  depends_on = ["k8s_manifest.nginx-namespace"]
  content   = "${data.template_file.nginx-deployment.rendered}"
  namespace = "nginx"
}
