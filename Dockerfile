# Container image that runs your code
FROM ubuntu:18.04
RUN ["apt", "update"] 
RUN ["apt", "install", "-y", "git"] 

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]

ENV WITH_V ${WITH_V}
ENV RELEASE_BRANCHES ${RELEASE_BRANCHES}
ENV SOURCE ${SOURCE}
ENV DRY_RUN ${DRY_RUN}
ENV DEFAULT_BUMP ${DEFAULT_BUMP}

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
