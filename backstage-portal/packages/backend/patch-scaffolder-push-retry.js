/**
 * Patches @backstage/plugin-scaffolder-node to add retry logic with delay
 * before git push, working around the GitHub race condition where the repo
 * is created via API but not yet available on git servers.
 *
 * Applied during Docker build via Dockerfile.
 */
const fs = require('fs');
const path = require('path');

const filePath = path.join(
  __dirname,
  '../../node_modules/@backstage/plugin-scaffolder-node/dist/actions/gitHelpers.cjs.js',
);

let content = fs.readFileSync(filePath, 'utf8');

// Replace the direct push call with a retry loop that has a delay
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

if (!content.includes(original)) {
  console.error('ERROR: Could not find the expected code to patch in gitHelpers.cjs.js');
  console.error('The file may have been updated. Check the patch script.');
  process.exit(1);
}

content = content.replace(original, patched);
fs.writeFileSync(filePath, content, 'utf8');
console.log('Successfully patched gitHelpers.cjs.js with push retry logic (3 retries, 3s delay)');
