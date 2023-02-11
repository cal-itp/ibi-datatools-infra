The documentation at https://data-tools-docs.ibi-transit.com/en/latest/dev/deployment/ is pretty good as far as a general guide. To deploy this into GCP, we would need:

* An Auth0 account to link it to. Auth0 is used as the authentication provider for the application. It would probably take a lot to be comfortable with that as a long-term solution, but are we comfortable with it in the short term? Would this be the kind of thing where we're trying out this solution and, if we like it, we'll set up a state contract with IBI to go further?
* A PostgreSQL database and a Mongo database. Postgres through CloudSQL is pretty straightforward. Is that how we'd want to go? Probably. We already use some managed services, like all of Airflow through Cloud Composer. I suppose we'd want to do a similar thing with Mongo -- i.e. use the managed service ([MongoDB Atlas](https://cloud.google.com/mongodb)).
* What do we have to be aware of for running the application? It has a client repository and a server repository that are expected to run independently. Two pods in a cluster? I have to check on the expectations around parallelism (I expect it's no big deal for the UI, but for the server?).

## Server
* Uses auth0. How do we deal with that? We can [disable auth](https://data-tools-docs.ibi-transit.com/en/latest/dev/deployment/#setting-up-auth0), but then of course we wouldn't have auth.
* There are a bunch of places in the code where `s3Bucket` is used. But it seems that's primarily needed for OTP integration, which isn't a necessity
* The service is tuned for postgres, so that will have to be costed out; Also uses MongoDB. PostgreSQL is used for schedule data; we can run that in a Cloud SQL instance. Mongo is just used for application runtime info, so can be run in-cluster.
* Configured with YML config files (which is unfortunate; would prefer env vars). Using k8s configmaps seems to be the way to go for those in the cluster, but is there a way to do it without checking credentials into git :-/?
* After setting up the env.yml file appropriately (specifically `MONGO_HOST` and `GTFS_DATABASE_URL`), the server runs fine in Docker.

## UI
* I could not install the dependencies with npm, but I was able to with yarn (as is directed in the docs); it seems to be less strict with dependency conflicts.
* I was repetedly receiving failures while the build step was trying to generate source maps, so I commented out line 56 in mastarm/lib/css-transform.js.
* I was not able to get the `DISABLE_AUTH` setting to be respected, so that could make operating without auth0 tricky.
* Also Mapbox. It uses a mapbox API token to get tiles.

### Errors:
* Upon logging in using Auth0 (with what I thought was a correct configuration), I got a "Auth0 user authentication is not configured properly!" error in the console. It was because I didn't follow this step: https://data-tools-docs.ibi-transit.com/en/latest/dev/deployment/#auth0-rule-configuration-making-app_metadata-and-user_metadata-visible-via-token-only-required-for-new-auth0-accountstenants. Note that **Rules** is under **Auth Pipeline** in the Auth0 admin interface. Make sure to clear cookies and local storage if you also forgot (like me).
* I kept getting the error "Could not verify user's token". I found out from https://bytemeta.vip/repo/ibi-group/datatools-server/issues/335 that I should disable the `AUTH0_SECRET` environment variable, and set the `AUTH0_PUBLIC_KEY` variable. I found out how to get the public key (pem) file from https://community.auth0.com/t/where-is-the-auth0-public-key-to-be-used-in-jwt-io-to-verify-the-signature-of-a-rs256-token/8455. Use https://[your-app-domain]/pem

### Local development:

* Use Kubernetes in Docker (kind) to create a local k8s cluster

  ```console
  $ kind create cluster --config datatools-infra/kind-config.yaml

  Creating cluster "kind" ...
  ✓ Ensuring node image (kindest/node:v1.25.3) 🖼
  ✓ Preparing nodes 📦 📦  
  ✓ Writing configuration 📜 
  ✓ Starting control-plane 🕹️ 
  ✓ Installing CNI 🔌 
  ✓ Installing StorageClass 💾 
  ✓ Joining worker nodes 🚜 
  Set kubectl context to "kind-kind"
  You can now use your cluster with:

  kubectl cluster-info --context kind-kind

  Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
  ```

* Build the appropriate Docker images.

  ```console
  $ docker build --tag ibi-datatools-server .
  ```

* Load the images into the kind container repository

  ```console
  $ kind load docker-image ibi-datatools-server

  Image: "" with ID "sha256:[...]" not yet present on node "kind-control-plane", loading...
  ```

* Apply the k8s configuration

  ```console
  $ kubectl apply -f manifests/datatools-server
  ```

This guide is a good one: https://kubectl.docs.kubernetes.io/guides/introduction/

