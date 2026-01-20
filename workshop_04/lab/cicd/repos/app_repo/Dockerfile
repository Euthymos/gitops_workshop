# Build
FROM registry.access.redhat.com/ubi9/nodejs-20 AS build

WORKDIR /opt/app-root/src

COPY package.json ./

RUN npm install

COPY . .

RUN npm run build

# Serve
FROM registry.access.redhat.com/ubi9/nginx-126

USER root

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build --chown=1001:0 /opt/app-root/src/dist /opt/app-root/src

USER 1001
EXPOSE 8080

CMD nginx -g "daemon off;"