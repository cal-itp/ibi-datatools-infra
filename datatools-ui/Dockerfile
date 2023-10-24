FROM node:14

# checkout a fork of the project that hacks the UI such that no 
# authentication is necessary for creating feeds, feed versions
# and using the GTFS editor
RUN git clone https://github.com/evansiroky/datatools-ui.git
WORKDIR /datatools-ui
RUN git checkout 46c2a8804b2805efb2c30bffb3f1cd2546b48a10

# build the project
RUN yarn
COPY env.yml /datatools-ui/configurations/default
RUN yarn run build-dev

# expose built files via nginx
FROM nginx
COPY --from=0 /datatools-ui/dist /usr/share/nginx/html/dist/
EXPOSE 80