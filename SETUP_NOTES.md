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
* I was repetedly receiving failures while the build step was trying to generate source maps, so I commented out line 56 in mastarm/lib/css-transform.js -- specifically the one that reads:
  ```js
  ...
  if (results.map) {
    // fs.writeFileSync(`${outfile}.map`, results.map)  <-- Commented this line.
  }
  ...
  ```
* I was not able to get the `DISABLE_AUTH` setting to be respected, so that could make operating without auth0 tricky.
* Also Mapbox. It uses a mapbox API token to get tiles.
* For a "production" build, I just ran `yarn run build --minify -c configuration/default`, as adapted from  the Dockerfile. That created a `dist/` folder, so I just `python3 -m http.server --directory dist/` to serve it up.

### Errors:
* Upon logging in using Auth0 (with what I thought was a correct configuration), I got a "Auth0 user authentication is not configured properly!" error in the console. It was because I didn't follow this step: https://data-tools-docs.ibi-transit.com/en/latest/dev/deployment/#auth0-post-login-action-configuration-making-app_metadata-and-user_metadata-visible-via-token. Make sure to clear cookies and local storage if you also forgot (like me).
* I kept getting the error "Could not verify user's token". I found out from https://bytemeta.vip/repo/ibi-group/datatools-server/issues/335 that I should disable the `AUTH0_SECRET` environment variable, and set the `AUTH0_PUBLIC_KEY` variable. I found out how to get the public key (pem) file from https://community.auth0.com/t/where-is-the-auth0-public-key-to-be-used-in-jwt-io-to-verify-the-signature-of-a-rs256-token/8455. Use https://[your-app-domain]/pem

### Bootstraping a k8s configuration with `kompose`

0.  In the datatools-server docker-compose.yml file, add a `datatools-ui` service that exposes port `80` on `9966`:
    ```yml
    datatools-ui:
      build: ../datatools-ui
      ports:
        - "9966:80"
    ```
    Add the `datatools-ui` service to the `datatools-server.depends_on` list. In order for the server to correctly serve the user interface, the UI service has to be available and serving the static assets. Alternatively these assets could be deployed somewhere publicly accessible, but this seems easiest.

1. Install `kompose` and run it from the root directory:
    ```console
    $ mkdir kompose-test
    $ kompose convert \
        -f datatools-server/docker-compose.yml \
        -o kompose-test
    ```

2.  In the resulting YAML files, get rid of any `annotations` sections; they're unnecessary.

### Local development (with just Docker):

* Pre-requisites:
  * The _docker-compose.yml_ file from this repository.
  * Check out both the [datatools-ui](https://github.com/ibi-group/datatools-ui) and [datatools-server](https://github.com/ibi-group/datatools-server) repositories as subfolders of the same folder.
  * An Auth0 account, configured as specified in https://data-tools-docs.ibi-transit.com/en/latest/dev/deployment/#setting-up-auth0.

* In your _datatools-server/configurations/default/_ folder, configure a _server.yml_ and an _env.yml_ file. The _server.yml_ file will be identical to the template, with the exception of the `client_assets_url` property. Change that to `http://localhost:9966`. The _env.yml_ file will have the following properties:
  ```yml
  # This client ID refers to the UI client in Auth0.
  AUTH0_CLIENT_ID: ...
  AUTH0_DOMAIN: ...
  AUTH0_PUBLIC_KEY: /config/auth0-public-key.pem
  # This client/secret pair refer to a machine-to-machine Auth0 application used to access the Management API.
  AUTH0_API_CLIENT: ...
  AUTH0_API_SECRET: ...
  DISABLE_AUTH: false

  OSM_VEX: http://localhost:1000
  SPARKPOST_KEY: your-sparkpost-key
  SPARKPOST_EMAIL: email@example.com

  GTFS_DATABASE_URL: jdbc:postgresql://postgres/dmtest
  # GTFS_DATABASE_USER:
  # GTFS_DATABASE_PASSWORD:

  MONGO_DB_NAME: catalogue
  MONGO_HOST: mongo:27017
  # MONGO_PASSWORD:
  # MONGO_USER:
  ```

* Download your Auth0 public key and save it to a file named _./datatools-server/configurations/default/auth0-public-key.pem_.

* In the _datatools-ui/_ folder, create a _Dockerfile_ with the following contents:
  
  ```dockerfile
  # =================================================================================================
  # The following is based on https://github.com/ibi-group/datatools-ui/issues/831#issuecomment-1212006536
  FROM node:14
  WORKDIR /datatools-build
  RUN cd /datatools-build
  COPY package.json yarn.lock /datatools-build/
  RUN yarn
  COPY . /datatools-build/
  COPY configurations/default /datatools-config/
  RUN yarn run build --minify -c /datatools-config

  FROM nginx
  COPY --from=0 /datatools-build/dist /usr/share/nginx/html/dist/
  EXPOSE 80
  ```

* Use Docker Compose to build and run the containers:

  ```console
  $ docker-compose build
  $ docker-compose up
  ```

The server should be available at http://localhost:4000 🙌!

### Local development (with Kubernetes):

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
  $ docker build --tag ibi-datatools-ui .
  ```

  ... and ...

  ```console
  $ docker build --tag ibi-datatools-server .
  ```

* Load the images into the kind container repository

  ```console
  $ kind load docker-image ibi-datatools-ui

  Image: "" with ID "sha256:[...]" not yet present on node "kind-control-plane", loading...
  ```

  ... and ...

  ```console
  $ kind load docker-image ibi-datatools-server

  Image: "" with ID "sha256:[...]" not yet present on node "kind-control-plane", loading...
  ```

* Apply the k8s configuration

  ```console
  $ kubectl apply -f manifests/datatools-server
  ```

* Set up an nginx ingress controller

  ```console
  $ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  ```

This guide is a good one: https://kubectl.docs.kubernetes.io/guides/introduction/

