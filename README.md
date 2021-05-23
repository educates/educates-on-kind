Educates on Kind
================

This repository holds scripts for deploying a Kubernetes Kind cluster with
an image registry, Contour ingress controller, and pod security policies
enabled, as well as then deploying Educates to the cluster.

This Kind cluster configuration is intended for doing development work on
Educates or for local creation of Educates workshop content.

The scripts assume you aren't already running a Kind cluster.

You will need to have ``docker`` and ``kind`` installed.

Configuration
-------------

Before you create the Kind cluster you need to indicate what domain name
should be used for ingresses created in the cluster.

If you do not have access to your own domain name which you can map to a
specific IP address by updating DNS, you will need to use a ``nip.io``
address.

In this case, calculate the IP address of your local machine where the Kind
cluster is to be run.

Create a file called ``local-settings.env`` in this directory and add to it:

```
INGRESS_DOMAIN=192.168.1.1.nip.io
```

Replace ``192.168.1.1`` with the IP address of your local machine.

If you have your own domain name, you should create a wildcard sub domain and
map that to the IP address of your local machine.

For example, if you owned the domain name ``educates.io``, you would create
a wildcard sub domain something like ``*.labs.educates.io`` mapping to the
IP address of your local machine.

In the ``local-settings.env`` file you would then add:

```
INGRESS_DOMAIN=labs.educates.io
```

Where using your own sub domain, LetsEncrypt can be used to create a
wildcard certificate for the sub domain. This will allow you use secure
ingresses when accessing workshops deployed using Educates.

If you do not have a certificate you can use for the sub domain, certain
types of Educates workshops will not work. This includes workshops which
enable an image registry per workshop session and which attempt to deploy
to the Kubernetes cluster images stored in that image registry.

Once you have a wildcard certificate, it should be stored as a Kubernetes
secret in a file with name of the form:

```
educates-resources/${INGRESS_DOMAIN}-tls.yaml
```

The name of the secret should be of the form:

```
${INGRESS_DOMAIN}-tls
```

If you used ``certbot`` to create a wildcard certificate, you can generate
the secret file using a command like:

```
kubectl create secret tls ${INGRESS_DOMAIN}-tls \
 --cert=$HOME/.letsencrypt/config/live/${INGRESS_DOMAIN}/fullchain.pem \
 --key=$HOME/.letsencrypt/config/live/${INGRESS_DOMAIN}/privkey.pem \
 --dry-run=client -o yaml > educates-resources/${INGRESS_DOMAIN}-tls.yaml
```

Installation
------------

To create the Kind cluster you can now run:

```
./create-cluster.sh
```

Once the Kind cluster has been created, you can deploy the Educates operator
by running:

```
./deploy-educates.sh
```

Testing
-------

Once the Kind cluster has been created and Educates installed, to test that
Educates is working, you can deploy the Educates tutorials by running:

```
kubectl apply -k github.com/eduk8s/eduk8s-tutorials
```

Note that the first time deploying and accessing any Educates workshop will
be slower as the various container images will need to be pulled down.

To get the URL for accessing the tutorials run:

```
kubectl get trainingportal/eduk8s-tutorials
```

The password for accessing the tutorials is ``educates``.

The Educates tutorials can be deleted by running:

```
kubectl apply -k github.com/eduk8s/eduk8s-tutorials
```

Registry
--------

To accompany the Kind cluster, an image registry is deployed direct to
the local ``docker`` runtime. That is, not within the Kind cluster itself.

This image registry can be used to hold custom workshop images or OCI
image artifacts holding workshop content for Educates.

If building a custom workshop image, tag it as:

```
registry.${INGRESS_DOMAIN}:5000/custom-workshop-image:latest
```

and push it to the image registry. You can then reference the custom
workshop image in a ``Workshop`` definition from the same image location
by setting the ``spec.content.image`` field.

For workshop content, you can use the command:

```
imgpkg push -i ${INGRESS_DOMAIN}:5000/workshop-content:latest --registry-insecure -f .
```

to create the OCI artifact for the workshop content and push it to the
image registry. You can then reference the workshop content in a
``Workshop`` definition from the same image location by setting the
``spec.content.files`` field to a value of the form:

```
imgpkg+http://${INGRESS_DOMAIN}:5000/workshop-content:latest
```

Access to the image registry is always over an insecure connection.
There is no authentication so anyone can push images to the image
registry.

By default the image registry will only be accessible from your local
machine. If you want to make it accessible on your local network so you
can push images to it from another machine, you can add:

```
REGISTRY_HOST=0.0.0.0
```

to ``local-settings.env`` before the image registry gets created as part
of creating the Kind cluster the first time.

Deletion
--------

To delete the Kind cluster you can run:

```
./delete-cluster.sh
```

If you only wanted to delete Educates you could have run:

```
./delete-educates.sh
```

Even after the Kind cluster has been deleted, the local image registry will
still exist as it runs directly in the local ``docker`` runtime.

To delete the image registry you can run:

```
./delete-registry.sh
```
