FROM node:20-alpine

WORKDIR /app

# Copy package files and install deps
COPY package*.json ./
COPY angular.json ./
COPY tsconfig*.json ./
COPY proxy*.conf.json ./
RUN npm ci --no-fund --no-audit

# Copy the rest of the app
COPY . .

EXPOSE 4200

# Use docker-specific proxy to reach backend container by service name
CMD ["npm", "run", "start", "--", "--host", "0.0.0.0", "--port", "4200", "--proxy-config", "proxy.docker.conf.json"] 