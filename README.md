Educates on Kind
================

This repository holds scripts for deploying a Kubernetes Kind cluster with
an image registry, Contour ingress controller, and pod security policies
enabled, as well as then deploying Educates to the cluster.

This Kind cluster configuration is intended for doing development work on
Educates or for local creation of Educates workshop content.

The scripts assume you aren't already running a Kind cluster.

You will need to have ``docker`` and ``kind`` installed, and if using Docker
Desktop ensure you have configured it with enough memory resources to be able
to run a Kind Kubernetes cluster with Educates, as well as the hosted
workshops.

Configuration
-------------

Before you create the Kind cluster you need to indicate what domain name
should be used for ingresses created in the cluster.

If you do not have access to your own domain name which you can map to a
specific IP address by updating DNS, you will need to use a ``nip.io``
address.

In this case, calculate the IP address of your local machine where the Kind
cluster is to be run. You cannot use ``127.0.0.1`` or ``localhost`` for this.

Create a file called ``local-settings.env`` in this directory and add to it:

```
INGRESS_DOMAIN=192.168.1.1.nip.io
```

Replace ``192.168.1.1`` with the IP address of your local machine.

If you have your own domain name, you can create a wildcard sub domain and
map that to the IP address of your local machine in the DNS server which you
use to manage your domain.

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

To accompany the Kind cluster, an image registry is deployed direct to
the local ``docker`` runtime. That is, not within the Kind cluster itself.

This image registry can be used to hold custom workshop images or OCI image
artifacts holding workshop content for Educates. It can also be used when
testing disconnected installs of Educates.

If you do not intend using the local image registry you can skip down to
installation, otherwise continue with the configuration steps.

The local image registry will by default not require authentication. To
enable authentication create a file with the credentials using
``htpasswd``. Call this file ``educates-resources/htpasswd``. Ensure that
``bcrypt`` is used when encrypting the password.

```
htpasswd -Bbn educates educates > educates-resources/htpasswd
```

Enabling authentication is not required, but should be done if access to
the local image registry from outside of the local machine is required and
you are not on a private network.

When authentication is enabled you will be required to login to the image
registry before you can push images to it using ``docker``, and image pull
secrets will need to be used with deployments created in the Kubernetes
cluster. If using others tools such as ``skopeo`` or ``imgpkg`` and you
haven't logged into the local image registry using ``docker`` you would
need to supply credentials to those tools on the command line as necessary.

Even when supplying a certificate to enable secure ingress for Educates,
access to the local image registry will still by default be insecure.

If you want access to the local image registry to also be secure, you need
to also copy the original wildcard certificate and private key into the
``educates-resources`` directory before the image local image registry is
created.

```
cp $HOME/.letsencrypt/config/live/${INGRESS_DOMAIN}/fullchain.pem educates-resources/${INGRESS_DOMAIN}-tls.crt
cp $HOME/.letsencrypt/config/live/${INGRESS_DOMAIN}/privkey.pem educates-resources/${INGRESS_DOMAIN}-tls.key
```

If you need to make the local image registry accessible on your local
network so you can push images to it from another machine, you can add:

```
REGISTRY_HOST=0.0.0.0
```

to ``local-settings.env`` before the image registry gets created.

Note that access to the local image registry must be secure and the local
image registry exposed to the local network if using ``imgpkg copy`` to do
testing of disconnected installation of Educates.

Also, you will need to allow access from the local network if wishing to
use the local image registry to host workshop content as an OCI image
artifact.

In these latter two cases exposing the local image registry to the local
network is required because normally the image registry would only listen
for connections on ``localhost``, but in these cases it must be able to
accept connections on the IP address of your local machine as that is what
the fully qualified hostname in DNS will map to.

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

Registry
--------

By default access to the image registry will be over an insecure connection
and there is no authentication so anyone can push images to the image
registry. The image registry will also by default only be accessible from
your local machine.

When building images and pushing them to the local image registry, you
should use the registry server address of ``localhost:5000`` when insecure
connections are being used. Deployments made in the Kind cluster can also
use ``localhost:5000`` when referring to images stored in the local image
registry and these will be automatically mapped through to the local image
registry.

The local docker daemon when doing a push should automatically accept the
local image registry as being insecure. Other tools such as ``skopeo`` or
``imgpkg`` may need to be told to accept the local image registry as being
insecure.

If building a custom workshop image, you can tag it as:

```
localhost:5000/custom-workshop-image:latest
```

and then push it to the local image registry.

You can then reference the custom workshop image in a ``Workshop``
definition from the same image location by setting the
``spec.content.image`` field to the same image reference.

If you have exposed the local image registry to the local network, and your
local docker daemon has also been configured to trust the registry hostname
even though insecure, you can instead in each case also use:

```
registry.${INGRESS_DOMAIN}:5000/custom-workshop-image:latest
```

The local image registry can be used to host workshop content as an OCI
image artifact, but this will only work if you have exposed the local image
registry to the local network.

To create the OCI image artifact for the workshop content use the command:

```
imgpkg push -i registry.${INGRESS_DOMAIN}:5000/workshop-content:latest --registry-insecure -f .
```

When referencing the workshop content in a ``Workshop`` definition from the
same image location by setting the ``spec.content.files`` field, use a
value of the form:

```
imgpkg+http://registry.${INGRESS_DOMAIN}:5000/workshop-content:latest
```

If you have enabled secure access to the local image registry, the port
number for the local image registry will be different, with it being
changed from ``5000`` to ``5443``. You also will not need to use the
``--registry-insecure`` option with ``imgpkg push``. Where a URI is used
and it specifies the protocol of ``http``, this should be changed to
``https``.

If you have enabled authentication for the local image registry you will be
required to login to the image registry before you can push images to it
using ``docker``, and image pull secrets will need to be used with
deployments created in the Kubernetes cluster. If using others tools such
as ``skopeo`` or ``imgpkg`` and you haven't logged into the local image
registry using ``docker`` you would need to supply credentials to those
tools on the command line as necessary.

In the case of workshop content packaged as an OCI image artifact, you will
need to supply any image registry credentials in the value set using
``spec.content.files``.

```
imgpkg+https://educates:educates@registry.${INGRESS_DOMAIN}:5443/workshop-content:latest
```

Testing
-------

Once the Kind cluster has been created and Educates installed, to test that
Educates is working, you can deploy the Educates tutorials by running:

```
kubectl apply -k github.com/educates/educates-tutorials
```

Note that the first time deploying and accessing any Educates workshop will
be slower as the various container images will need to be pulled down.

To get the URL for accessing the tutorials run:

```
kubectl get trainingportal/educates-tutorials
```

The password for accessing the tutorials is ``educates``.

The Educates tutorials can be deleted by running:

```
kubectl delete -k github.com/educates/educates-tutorials
```

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
