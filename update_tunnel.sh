set -e

STREAMLIT_PORT=8501      
REPO_DIR="$(pwd)"          
LOG_FILE="/tmp/cloudflared.log"

echo "start cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:${STREAMLIT_PORT}" > "$LOG_FILE" 2>&1 &
CF_PID=$!

echo "wait for tunnel URL ..."
URL=""
for i in {1..30}; do
  URL=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' "$LOG_FILE" | head -n 1 || true)
  if [ -n "$URL" ]; then
    break
  fi
  sleep 1
done

if [ -z "$URL" ]; then
  echo "failed to fetch URL，checking $LOG_FILE to see if cloudflared is activated"
  exit 1
fi

echo "Get URL: $URL"

perl -pi -e "s|const currentUrl = \".*?\";|const currentUrl = \"$URL\";|" "$REPO_DIR/index.html"

cd "$REPO_DIR"
git add index.html
git commit -m "Update tunnel URL to $URL"
git push

echo "Updated and pushed to GitHub Pages，wait for a minute。"
echo "cloudflared is active (PID: $CF_PID)，press Ctrl+C or manually kill $CF_PID tp stp[。"

wait $CF_PID
