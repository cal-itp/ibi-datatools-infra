#!/usr/bin/env bash

set -e

DATATOOLS_SERVER_COMMIT="d61c75767b9b8dcaf8da36c4fe1bd5a747d0f711" # dev HEAD as of Apr 26 2023
DATATOOLS_CLIENT_ASSETS_URL=http://localhost9966

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# If the $ROOT/datatools-server folder doesn't exist, check it out from
# https://github.com/ibi-group/datatools-server.git
if [ ! -d "$ROOT/datatools-server" ]; then
  git clone https://github.com/ibi-group/datatools-server.git "$ROOT/datatools-server"
fi

# Make sure we're on the intended commit
cd "$ROOT/datatools-server"
git fetch
git checkout $DATATOOLS_SERVER_COMMIT

# Change into the configuration files folder
cd "$ROOT/datatools-server/configurations/default"

# Generate an env.yml configuratin file
echo "Generating env.yml configuration file..."
cat > env.yml <<EOF
# This client ID refers to the UI client in Auth0.
AUTH0_CLIENT_ID: ${AUTH0_CLIENT_ID}
AUTH0_DOMAIN: ${AUTH0_DOMAIN}
AUTH0_PUBLIC_KEY: /config/auth0-public-key.pem
# This client/secret pair refer to a machine-to-machine Auth0 application used to access the Management API.
AUTH0_API_CLIENT: ${AUTH0_API_CLIENT}
AUTH0_API_SECRET: ${AUTH0_API_SECRET}
DISABLE_AUTH: false

OSM_VEX: http://localhost:1000

SPARKPOST_KEY: your-sparkpost-key
SPARKPOST_EMAIL: email@example.com

GTFS_DATABASE_URL: jdbc:postgresql://postgres/datatools # If running via docker, this is jdbc:postgresql://postgres/dmtest
# GTFS_DATABASE_USER:
# GTFS_DATABASE_PASSWORD:

MONGO_DB_NAME: catalogue
MONGO_HOST: mongo:27017 # If running via docker, this is mongo:27017
# MONGO_PASSWORD: password
# MONGO_USER: admin
EOF

# Copy the server.yml template and replace the client_assets_url line
echo "Generating server.yml configuration file..."
cp server.yml.tmp server.yml
sed -i "s|client_assets_url: .*|client_assets_url: ${DATATOOLS_CLIENT_ASSETS_URL}|" server.yml

# Create the auth0-public-key.pem file
echo "Generating auth0-public-key.pem file..."
echo "$AUTH0_PUBLIC_KEY" > auth0-public-key.pem

echo "Done."