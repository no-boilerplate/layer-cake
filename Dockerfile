FROM node:4
WORKDIR /app
ADD package.json /app/
RUN npm install && npm install -g coffee-script
ADD app.litcoffee /app/
ADD lib /app/lib/
ENTRYPOINT ["coffee", "/app/app.litcoffee"]
