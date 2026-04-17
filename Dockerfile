FROM node:20-alpine

WORKDIR /app

COPY installer/setup.ps1 ./installer/setup.ps1
COPY installer/setup.sh ./installer/setup.sh
COPY installer/web/package.json ./installer/web/package.json
COPY installer/web/server.js ./installer/web/server.js
COPY installer/web/index.html ./installer/web/index.html

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "installer/web/server.js"]
