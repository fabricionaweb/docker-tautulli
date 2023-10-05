# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.18 AS base
ARG BRANCH
ARG VERSION
ENV TZ=UTC

# source stage =================================================================
FROM base AS source
WORKDIR /src

# mandatory build-arg
RUN test -n "$BRANCH" && test -n "$VERSION"

# get and extract source from git
ADD https://raw.githubusercontent.com/Tautulli/tautulli-baseimage/python3/requirements.txt ./requirements-base.txt
ADD https://github.com/Tautulli/Tautulli.git#v$VERSION ./

# tautulli versioning
RUN echo "$BRANCH" > branch.txt && echo "v$VERSION" > version.txt

# dependencies
# RUN apk add --no-cache patch

# apply available patches
# COPY patches ./
# RUN find . -name "*.patch" -print0 | sort -z | xargs -t -0 -n1 patch -p1 -i

# build stage ==================================================================
FROM base AS build-backend
WORKDIR /src

# dependencies
RUN apk add --no-cache build-base python3-dev git libffi-dev

# copy requirements
COPY --from=source /src/requirements*.txt ./

# creates python env
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install -r requirements-base.txt -r requirements.txt

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
ENV TAUTULLI_DOCKER=true
WORKDIR /config
VOLUME /config
EXPOSE 8181

# copy files
COPY --from=build-backend /opt/venv /opt/venv
COPY --from=source /src /app
COPY ./rootfs /

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay python3 curl

# creates python env
ENV PATH="/opt/venv/bin:$PATH"

# run using s6-overlay
ENTRYPOINT ["/init"]
