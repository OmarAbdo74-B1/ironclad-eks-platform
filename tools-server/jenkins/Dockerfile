ARG TRIVY_VERSION
FROM aquasec/trivy:${TRIVY_VERSION} AS trivy

FROM jenkins/jenkins:lts-jdk21

USER root

# Docker CLI + buildx
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker/buildx-bin:latest /buildx /usr/libexec/docker/cli-plugins/docker-buildx

COPY --from=trivy /usr/local/bin/trivy /usr/local/bin/trivy

# Kustomize
ARG KUSTOMIZE_VERSION=5.4.3
RUN curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
    | tar xz -C /usr/local/bin kustomize

USER jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt