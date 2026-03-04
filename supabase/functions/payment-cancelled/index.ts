import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (_req: Request) => {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Cancelled</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      color: #fff;
    }
    .container {
      text-align: center;
      padding: 2rem;
      max-width: 420px;
    }
    .icon {
      font-size: 72px;
      margin-bottom: 1rem;
      animation: pop 0.5s ease;
    }
    @keyframes pop {
      0% { transform: scale(0); }
      80% { transform: scale(1.2); }
      100% { transform: scale(1); }
    }
    h1 {
      font-size: 1.8rem;
      margin-bottom: 0.5rem;
    }
    p {
      font-size: 1rem;
      opacity: 0.9;
      margin-bottom: 1.5rem;
      line-height: 1.5;
    }
    .btn {
      display: inline-block;
      padding: 12px 32px;
      background: rgba(255,255,255,0.2);
      border: 2px solid rgba(255,255,255,0.5);
      border-radius: 8px;
      color: #fff;
      text-decoration: none;
      font-size: 1rem;
      cursor: pointer;
      transition: background 0.2s;
    }
    .btn:hover { background: rgba(255,255,255,0.3); }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">\u274C</div>
    <h1>Payment Cancelled</h1>
    <p>The payment was not completed. No charges were made. You can close this tab and return to the app to try again.</p>
    <button class="btn" onclick="window.close()">Close This Tab</button>
  </div>
  <script>
    setTimeout(() => { try { window.close(); } catch(e) {} }, 8000);
  </script>
</body>
</html>`;

  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-cache',
    },
  });
});
