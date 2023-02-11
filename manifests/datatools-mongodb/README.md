All of these resources were borrowed from https://phoenixnap.com/kb/kubernetes-mongodb

For the persistent-volume.yaml configuration, I added a role to the kind node:

```bash
kubectl label nodes kind-worker customlabel=thirdpartytools
```

Then apply the configurations like so:

```bash
kubectl apply -k datatools-infra/manifests/datatools-mongodb/
```