FROM node:16.14.2 as build

WORKDIR /app

## Packages
COPY package.json /app/

RUN yarn

# Sources
COPY public/ /app/public/
COPY src/ /app/src/
COPY tsconfig.json /app/
COPY .env.production .env

RUN yarn build

#-----------------------

FROM nginx:1.23.2

COPY --from=build /app/build /usr/share/nginx/html
COPY ./nginx.conf /etc/nginx/