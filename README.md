# IBI Datatools Infra

This project is intended to establish a local-only zero-authentication instance of datatools. Use at your own risk!

## Setup

If you'd like to have a basemap and create shapes, you must create Mapbox and Graphhopper accounts respectively. Generate keys to use these services and add them to a `datatools-ui/env.yml` that has everything else copied over.

## Running everything

Build and run the images with docker:

```console
$ docker-compose build
$ docker-compose up
```

Then go to the following website: http://localhost:4000/project

## Notes

A number of features are assumed to not work with this setup such as:

- User management
- Deployment to OTP instances
- Saving data to the cloud
- Any kind of backup of the databases

The primary use case for this setup is to quickly edit GTFS feeds using datatool's editor. It is possible to keep track of feed versions, but it is highly recommended to download the GTFS data and save elsewhere for reliable persistence!