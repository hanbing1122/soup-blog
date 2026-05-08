#!/bin/bash
set -e
cd "$(dirname "$0")"

# Load CF token from env or .cf_token file (gitignored)
if [ -z "$CLOUDFLARE_API_TOKEN" ] && [ -f .cf_token ]; then
  export CLOUDFLARE_API_TOKEN=$(cat .cf_token)
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN not set."
  echo "  export CLOUDFLARE_API_TOKEN=cfut_xxx   or   echo cfut_xxx > .cf_token"
  exit 1
fi

echo "Building..."
npx hexo clean > /dev/null
npx hexo generate > /dev/null
echo "Deploying to CF Pages..."
npx wrangler pages deploy public/ --project-name soup-blog --branch main --commit-dirty=true
echo "Done → https://blog.soooup.org"
