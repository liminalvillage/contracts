# Use the official Node.js 18 image
FROM node:18

# Set the working directory inside the container
WORKDIR /app

# Copy just the hardhat directory contents
COPY hardhat/ .

# Install dependencies
RUN npm install

# Expose the port that Hardhat node will run on
EXPOSE 8545

# Command to run Hardhat node with specific host binding
CMD ["npx", "hardhat", "node", "--hostname", "0.0.0.0"]