'use strict';

/** HTML shown after OAuth when `?desktop=1` — no custom URL scheme required. */
function desktopAuthSuccessHtml(sessionToken) {
    const tokenJson = JSON.stringify(sessionToken);
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ClassGrid — signed in</title>
  <style>
    :root { font-family: system-ui, sans-serif; color: #1a1a18; background: #f6f4ef; }
    body { max-width: 36rem; margin: 2rem auto; padding: 0 1.25rem; line-height: 1.5; }
    h1 { font-size: 1.35rem; font-weight: 600; margin-bottom: 0.5rem; }
    p { color: #4a4844; font-size: 0.95rem; }
    textarea {
      width: 100%; min-height: 5rem; margin: 1rem 0;
      font-family: ui-monospace, monospace; font-size: 0.75rem;
      padding: 0.75rem; border: 1px solid #c8c4bc; border-radius: 6px;
      background: #fff; resize: vertical;
    }
    button {
      font: inherit; font-size: 0.9rem; padding: 0.55rem 1rem;
      border-radius: 6px; border: 1px solid #2a6f7a; background: #2a6f7a;
      color: #fff; cursor: pointer;
    }
    button:hover { filter: brightness(1.05); }
    .ok { color: #2d5a3d; font-size: 0.85rem; margin-top: 0.75rem; display: none; }
  </style>
</head>
<body>
  <h1>Signed in to ClassGrid</h1>
  <p>Copy the session token below, switch back to the ClassGrid desktop app, and paste it into the login dialog.</p>
  <textarea id="token" readonly aria-label="Session token"></textarea>
  <button type="button" id="copy">Copy token</button>
  <p class="ok" id="copied">Copied — paste in the app now.</p>
  <p>You can close this tab after pasting.</p>
  <script>
    const token = ${tokenJson};
    const el = document.getElementById('token');
    el.value = token;
    document.getElementById('copy').addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(token);
        document.getElementById('copied').style.display = 'block';
      } catch (e) {
        el.select();
        document.execCommand('copy');
        document.getElementById('copied').style.display = 'block';
      }
    });
  </script>
</body>
</html>`;
}

module.exports = { desktopAuthSuccessHtml };
