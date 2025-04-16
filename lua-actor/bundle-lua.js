import fs from 'fs';
import path from 'path';

// Parse command line arguments
const args = process.argv.slice(2);
let entryFile, outputFile;

// Handle command line arguments
if (args.length === 0) {
  console.log('Usage: node bundle-lua.js <entry-file> [output-file]');
  console.log('Example: node bundle-lua.js actor/src/apoc-v2.lua bundled-actor.lua');
  process.exit(1);
} else if (args.length === 1) {
  entryFile = args[0];
  // Default output file name based on the input file
  const baseName = path.basename(entryFile, '.lua');
  outputFile = `${baseName}-bundled.lua`;
} else {
  entryFile = args[0];
  outputFile = args[1];
}

const baseDir = process.cwd(); // Base directory for resolving paths

// Special case handling
const GLOBAL_MODULES = ['handlers', 'secp256k1']; // Modules provided globally by AOS
const WHITELIST_MODULES = ['base64', 'bint', 'json', 'crypto', 'utils']; // Modules to keep as-is

// Track processed modules to avoid circular dependencies
const processedModules = new Set();
const moduleContents = new Map();
const moduleOrder = []; // Track the order of modules for proper dependency resolution

// Process a Lua file and its dependencies
function processFile(filePath) {
  const absolutePath = path.isAbsolute(filePath) 
    ? filePath 
    : path.resolve(baseDir, filePath);

  if (processedModules.has(absolutePath)) {
    return moduleContents.get(absolutePath);
  }
  
  // Mark as processed to avoid circular dependencies
  processedModules.add(absolutePath);
  
  try {
    let content = fs.readFileSync(absolutePath, 'utf8');
    const directory = path.dirname(absolutePath);
    
    // Find all require statements
    const requireRegex = /local\s+(\w+)\s*=\s*require\s*\(\s*["']([^"']+)["']\s*\)/g;
    let match;
    const requires = [];
    
    // collect all require statements
    while ((match = requireRegex.exec(content)) !== null) {
      requires.push({
        fullMatch: match[0],
        variableName: match[1],
        modulePath: match[2]
      });
    }
    
    // Process each required module
    for (const req of requires) {
      let modulePath = req.modulePath;
      let originalModulePath = modulePath; // Store the original path for replacement

      // Handle global modules - We can remove these since they are provided globally by AOS module
      if (GLOBAL_MODULES.includes(modulePath)) {
        content = content.replace(req.fullMatch, '');
        continue;
      }

      // Handle whitelisted modules - We can keep these as-is, they are resolved in the AOS environment
      else if (isWhitelisted(modulePath)) {
        // AOS environment weirdly expects json library to be imported as "json" and other libraries to
        // be imported with a leading '.' character
        // Adding a '.' to the module path if it's not already there and it's not the json library
        // Could maybe update local lua environment to handle this but this is easier for now
        if (!modulePath.startsWith('.') && modulePath !== 'json') {
            const newModulePath = `.${modulePath}`;
            content = content.replace(
              new RegExp(`require\\s*\\(\\s*["']${escapeRegExp(modulePath)}["']\\s*\\)`, 'g'),
              `require("${newModulePath}")`
            );
        }
        continue;
      }
      
      // Resolve module path - consolidated logic
      if (modulePath.startsWith('.')) {
        // Relative path - resolve from current directory
        modulePath = path.resolve(directory, modulePath.replace(/^\./, '').replace(/\./g, path.sep));
      } else {
        // Non-relative path - treat dots as directory separators
        const entryDir = path.dirname(path.resolve(baseDir, entryFile));
        const normalizedPath = modulePath.replace(/\./g, path.sep);
        modulePath = path.resolve(entryDir, normalizedPath);
      }
      
      // Add .lua extension if missing
      if (!modulePath.endsWith('.lua')) {
        modulePath += '.lua';
      }
      
      // Update the require statement in the content to use the resolved path
      const relPath = path.relative(baseDir, modulePath).replace(/\\/g, '/').replace(/\.lua$/, '');
      content = content.replace(
        new RegExp(`require\\s*\\(\\s*["']${escapeRegExp(originalModulePath)}["']\\s*\\)`, 'g'),
        `__modules["${relPath}"]()`
      );
      
      // Process the required module ensuring proper dependency ordering by searching depth first
      processFile(modulePath);
      
      // Add to module order if not already included
      if (!moduleOrder.includes(modulePath)) {
        moduleOrder.push(modulePath);
      }
    }
    
    moduleContents.set(absolutePath, content);
    return content;
  } catch (error) {
    console.error(`Error processing file ${filePath}:`, error);
    process.exit(1);
  }
}

// Main bundling function
function bundleLua() {
  console.log(`Bundling Lua actor from ${entryFile} to ${outputFile}...`);
  
  // Process the entry file and all its dependencies
  processFile(entryFile);
  
  // Combine all modules into a single file
  let bundledContent = '';
  
  // Create module definitions for all dependencies
  // We'll define each module as a function and store it in a modules table
  bundledContent += '-- Module definitions\n';
  bundledContent += 'local __modules = {}\n';
  bundledContent += 'local __loaded = {}\n\n';
  
  // Add all dependencies in the correct order
  for (const modulePath of moduleOrder) {
    const relPath = path.relative(baseDir, modulePath);
    const moduleId = relPath.replace(/\\/g, '/').replace(/\.lua$/, '');

    bundledContent += `-- Begin module: ${relPath}\n`;
    bundledContent += `__modules["${moduleId}"] = function()\n`;
    bundledContent += `  if __loaded["${moduleId}"] then return __loaded["${moduleId}"] end\n`;
    
    // Get the module content
    let moduleContent = moduleContents.get(modulePath);
    
    bundledContent += `  local module = {}\n`;
    bundledContent += `  __loaded["${moduleId}"] = module\n\n`;
    
    // Add the module content
    bundledContent += moduleContent;
    
    // Fix: Capture the return value and assign it to module before returning
    bundledContent = bundledContent.replace(/return ([A-Za-z0-9_]+)(\s*)$/, function(match, returnValue) {
      return `  module = ${returnValue}\n  return module\n`;
    });
    
    // If the module doesn't explicitly return something, add a return statement
    if (!moduleContent.trim().endsWith('return') && !moduleContent.includes('\nreturn ')) {
      bundledContent += '\n  return module\n';
    }
    
    bundledContent += `end\n`;
    bundledContent += `-- End module: ${relPath}\n\n`;
  }
  
  // Add a require function that uses our modules table
  bundledContent += '-- Custom require function\n';
  bundledContent += 'local function __require(moduleName)\n';
  bundledContent += '  return __modules[moduleName]()\n';
  bundledContent += 'end\n\n';
  
  // Add the entry file content with modified require statements
  bundledContent += `-- Main actor file: ${entryFile}\n`;
  let entryContent = moduleContents.get(path.resolve(baseDir, entryFile));
  
  // Replace require statements in the entry file
  const entryRequireRegex = /local\s+(\w+)\s*=\s*require\s*\(\s*["']([^"']+)["']\s*\)/g;
  entryContent = entryContent.replace(entryRequireRegex, (match, varName, reqPath) => {
    // Skip global and whitelisted modules
    if (GLOBAL_MODULES.includes(reqPath) || isWhitelisted(reqPath)) {
      return match;
    }
    return `local ${varName} = __require("${reqPath}")`;
  });
  
  bundledContent += entryContent;
  
  // Write the bundled content to the output file
  fs.writeFileSync(outputFile, bundledContent);
  console.log(`Successfully bundled to ${outputFile}`);
}

// Run the bundler
bundleLua();

// Helper function to escape special characters in regex
function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function isWhitelisted(modulePath) {
  return WHITELIST_MODULES.some(module => modulePath === module || modulePath.startsWith(`.${module}`));
}