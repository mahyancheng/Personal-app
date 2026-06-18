import Foundation

/// Built-in HTML shown before/around the AI-generated screens: the welcome
/// screen (which also demos the native bridge) and the error screen.
enum UIHTML {

    static let welcome = #"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <style>
        :root { color-scheme: dark; }
        * { box-sizing: border-box; }
        body {
          margin: 0;
          font-family: -apple-system, system-ui, sans-serif;
          background: #0b0b0f; color: #f2f2f7;
          padding: 64px 20px calc(20px + env(safe-area-inset-bottom));
          -webkit-text-size-adjust: 100%;
        }
        h1 { font-size: 30px; margin: 0 0 6px; letter-spacing: -0.02em; }
        p.sub { color: #9a9aa2; margin: 0 0 28px; font-size: 16px; }
        .card {
          background: #16161c; border: 1px solid #26262e; border-radius: 18px;
          padding: 18px; margin-bottom: 14px;
        }
        .card h2 { font-size: 16px; margin: 0 0 6px; }
        .card p { font-size: 14px; color: #b6b6bf; margin: 0; line-height: 1.45; }
        button {
          appearance: none; border: 0; width: 100%; margin-top: 8px;
          background: #0a84ff; color: white; font-size: 16px; font-weight: 600;
          padding: 14px; border-radius: 14px; min-height: 44px;
        }
        button:active { opacity: .7; }
        #out { margin-top: 14px; }
        .ev { display:flex; justify-content:space-between; gap:10px;
              padding:12px 0; border-bottom:1px solid #26262e; font-size:14px; }
        .ev:last-child { border-bottom:0; }
        .ev .t { color:#8e8e96; white-space:nowrap; }
        .muted { color:#8e8e96; font-size:14px; }
      </style>
    </head>
    <body>
      <h1>Forge</h1>
      <p class="sub">Type what you need below. The AI writes the screen, this app renders it.</p>

      <div class="card">
        <h2>Try asking for…</h2>
        <p>“organize my day as a timeline”, “a 5-minute meditation timer”,
           “a quick expense logger”, “message my team I’m running 10 min late”.</p>
      </div>

      <div class="card">
        <h2>Live bridge check</h2>
        <p>This button calls the native calendar through the same bridge the AI uses.</p>
        <button onclick="showToday()">Show today’s schedule</button>
        <div id="out"></div>
      </div>

      <script>
        async function showToday() {
          const out = document.getElementById('out');
          out.innerHTML = '<p class="muted">Loading…</p>';
          try {
            const res = await nativeCall('calendar.list', { days: 1 });
            const events = (res && res.events) || [];
            if (!events.length) { out.innerHTML = '<p class="muted">Nothing on the calendar today.</p>'; return; }
            const fmt = (s) => new Date(s).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
            out.innerHTML = events.map(e =>
              '<div class="ev"><span>' + e.title + '</span>' +
              '<span class="t">' + fmt(e.start) + '</span></div>'
            ).join('');
          } catch (err) {
            out.innerHTML = '<p class="muted">Bridge error: ' + err + '</p>';
          }
        }
      </script>
    </body>
    </html>
    """#

    static func error(_ message: String) -> String {
        let safe = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return #"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <style>
            body { margin:0; font-family:-apple-system, system-ui, sans-serif;
                   background:#0b0b0f; color:#f2f2f7;
                   padding:80px 22px calc(22px + env(safe-area-inset-bottom)); }
            .icon { font-size:42px; }
            h1 { font-size:22px; margin:14px 0 8px; }
            pre { white-space:pre-wrap; word-break:break-word;
                  background:#16161c; border:1px solid #26262e; border-radius:14px;
                  padding:14px; color:#ff8f8f; font-size:13px; line-height:1.5; }
            p { color:#9a9aa2; font-size:15px; line-height:1.5; }
          </style>
        </head>
        <body>
          <div class="icon">⚠️</div>
          <h1>Couldn’t build that screen</h1>
          <pre>\#(safe)</pre>
          <p>Check your Base URL, API key, and model in Settings (gear icon), then try again.</p>
        </body>
        </html>
        """#
    }
}
