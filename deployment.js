import { mkdirSync, writeFileSync } from "fs";
import { resolve, dirname } from "path";

// Get arguments passed to the script
const filePath = process.argv[2];
const data = process.argv[3];

// Resolve the path
const resolvedPath = resolve(filePath);

// Ensure the directory exists
mkdirSync(dirname(resolvedPath), { recursive: true });

// Write the data to the file
writeFileSync(resolvedPath, data, "utf-8");

console.log(`File written successfully to ${resolvedPath}`);
