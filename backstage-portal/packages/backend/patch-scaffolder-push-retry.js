/**
 * Patches @backstage/plugin-scaffolder-node to add retry logic with delay
 * before git push, working around the GitHub race condition where the repo
 * is created via API but not yet available on git servers.
 *
 * Applied during Docker build via Dockerfile.
 * Patches ALL copies of gitHelpers.cjs.js (top-level and nested node_modules).
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Find ALL copies of gitHelpers.cjs.js in node_modules
const findCmd = "find /app/node_modules -path '*/plugin-scaffolder-node/dist/actions/gitHelpers.cjs.js' -type f";
let files;
try {
  files = execSync(findCmd, { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
} catch {
  // Fallback to known path if find fails
  files = [
    path.join(__dirname, '../../node_modules/@backstage/plugin-scaffolder-node/dist/actions/gitHelpers.cjs.js'),
  ];
}

const original = `  await git$1.push({
    dir,
    remote: "origin",
    url: remoteUrl
  });
  return { commitHash };`;

const patched = `  // Retry push with delay to work around GitHub race condition
  // where repo is created via API but git servers haven't propagated yet
  const maxRetries = 3;
  const delayMs = 3000;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      if (attempt > 1) {
        logger?.info(\`Push attempt \${attempt}/\${maxRetries} after \${delayMs}ms delay\`);
      }
      await git$1.push({
        dir,
        remote: "origin",
        url: remoteUrl
      });
      return { commitHash };
    } catch (pushError) {
      if (attempt < maxRetries && pushError.message?.includes('404')) {
        logger?.info(\`Push got 404, retrying in \${delayMs}ms (attempt \${attempt}/\${maxRetries})\`);
        await new Promise(resolve => setTimeout(resolve, delayMs));
      } else {
        throw pushError;
      }
    }
  }
  return { commitHash };`;

let patchedCount = 0;
for (const filePath of files) {
  try {
    let content = fs.readFileSync(filePath, 'utf8');
    if (content.includes(original)) {
      content = content.replace(original, patched);
      fs.writeFileSync(filePath, content, 'utf8');
      patchedCount++;
      console.log(`Patched: ${filePath}`);
    } else if (content.includes('Retry push with delay')) {
      console.log(`Already patched: ${filePath}`);
    } else {
      console.warn(`WARNING: Could not find expected code in ${filePath}`);
    }
  } catch (err) {
    console.error(`ERROR patching ${filePath}: ${err.message}`);
  }
}

if (patchedCount === 0) {
  console.error('ERROR: No files were patched! The push retry will not work.');
  process.exit(1);
}
console.log(`Successfully patched ${patchedCount} file(s) with push retry logic (3 retries, 3s delay)`);
