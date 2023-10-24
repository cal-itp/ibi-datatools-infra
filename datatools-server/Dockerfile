# syntax=docker/dockerfile:1
FROM maven:3.8.7-openjdk-18

RUN git clone https://github.com/ibi-group/datatools-server.git
WORKDIR /datatools-server
RUN git checkout d61c75767b9b8dcaf8da36c4fe1bd5a747d0f711

# setup config
COPY env.yml /datatools-server/configurations/default
COPY server.yml /datatools-server/configurations/default

# Build jar
RUN mvn package -DskipTests
RUN mv target/dt*.jar datatools-server.jar

RUN mkdir -p /var/datatools_gtfs/gtfsplus

# Launch server
# This relies on a configuration volume and aws volume being present. See `docker-compose.yml`, or the example below
# Try: docker run --publish 4000:4000 -v ~/config/:/config datatools-latest
CMD ["java", "-XX:MaxRAMPercentage=95", "-jar", "datatools-server.jar"]
EXPOSE 4000