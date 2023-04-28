#!/usr/bin/env bash

set -e

DATATOOLS_UI_COMMIT="77cb946fa17f7e7a42ed8447c7b387a6f6b19af0" # dev HEAD as of Apr 26 2023

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# If the $ROOT/datatools-ui folder doesn't exist, check it out from
# https://github.com/ibi-group/datatools-ui.git
if [ ! -d "$ROOT/datatools-ui" ]; then
  git clone https://github.com/ibi-group/datatools-ui.git "$ROOT/datatools-ui"
fi

# Make sure we're on the intended commit
cd "$ROOT/datatools-ui"
git fetch
git checkout $DATATOOLS_UI_COMMIT

# Copy over the Dockerfile that we should use
echo "Copying over the Dockerfile..."
cp "$ROOT/scripts/datatools-ui-Dockerfile" "$ROOT/datatools-ui/Dockerfile"

echo "Done."
