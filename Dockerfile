# Builder Phase
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

# Worker Phase
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app ./
ENV NODE_ENV=production
RUN npm prune --production || true
EXPOSE 3000
CMD ["npm","start"]
