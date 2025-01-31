FROM node:22.11.0

WORKDIR /usr/local/dist/

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