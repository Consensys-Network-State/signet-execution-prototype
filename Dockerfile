FROM node:22.11.0

WORKDIR /usr/local/dist/

RUN corepack enable
RUN corepack prepare yarn@4.1.0 --activate
ENV YARN_VERSION 4.1.0

# cache packages
COPY package.json ./
COPY yarn.lock ./

# install node dependencies
RUN yarn install

COPY . .

# Expose the port your Nest.js application is listening on
EXPOSE ${PORT:-4000}

# Command to start your Nest.js application
CMD [ "yarn", "start:prod" ]