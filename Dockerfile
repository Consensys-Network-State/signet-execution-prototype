FROM node:22.11.0

WORKDIR /usr/local/dist/

ENV YARN_VERSION 4.1.0
RUN yarn policies set-version $YARN_VERSION
RUN yarn config set nodeLinker node-modules

# cache packages
COPY package.json ./
COPY yarn.lock ./

# install node dependencies
RUN yarn install

COPY . .

# Expose the port your Nest.js application is listening on
EXPOSE 3000

# Command to start your Nest.js application
CMD [ "yarn", "start:prod" ]