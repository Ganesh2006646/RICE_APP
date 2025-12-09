FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY prisma ./prisma/
COPY tsconfig.json ./
COPY src ./src/

RUN npx prisma generate
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
