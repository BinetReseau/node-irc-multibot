FROM nodesource/node:latest

RUN npm install -g n; n latest
RUN npm install -g npm

RUN mkdir /app
WORKDIR /app
ADD package.json /app/
RUN npm install

ADD . /app

EXPOSE 3000
CMD npm start
