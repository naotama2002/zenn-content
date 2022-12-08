FROM node:14.11.0-alpine3.12
RUN apk add --no-cache --update git
RUN npm init --yes
RUN npm install zenn-cli
