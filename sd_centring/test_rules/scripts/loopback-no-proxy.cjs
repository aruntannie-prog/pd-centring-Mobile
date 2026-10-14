'use strict';
// Preloaded into the Firebase CLI (via NODE_OPTIONS=--require) by `npm run test:emulators`.
//
// Why: firebase-tools sends every API request through HTTPS_PROXY when it is
// set, and ignores NO_PROXY — even for its own calls to local emulators. The
// Storage emulator checks `firestore.exists(...)` in storage.rules by calling
// the Firestore emulator on 127.0.0.1; behind a proxy that call is sent to the
// proxy, fails, and every staff check silently becomes "not staff".
//
// This keeps HTTPS_PROXY in place for real outbound traffic and only sends
// loopback destinations (localhost / 127.x / ::1) directly. Without a proxy in
// the environment it does nothing.

const path = require('node:path');

function isLoopback(host) {
  const h = String(host).replace(/^\[|\]$/g, '').toLowerCase();
  return h === 'localhost' || h === '::1' || /^127\./.test(h);
}

try {
  const hasProxy = ['HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'http_proxy'].some((k) => process.env[k]);
  if (hasProxy) {
    const toolsDir = path.dirname(require.resolve('firebase-tools/package.json'));
    const undici = require(require.resolve('undici', { paths: [toolsDir] }));
    const OriginalProxyAgent = undici.ProxyAgent;
    if (OriginalProxyAgent && !OriginalProxyAgent.__loopbackAware) {
      class LoopbackAwareProxyAgent extends undici.Dispatcher {
        constructor(opts) {
          super();
          this.proxied = new OriginalProxyAgent(opts);
          this.direct = new undici.Agent();
        }
        dispatch(opts, handler) {
          const origin = opts.origin instanceof URL ? opts.origin : new URL(String(opts.origin));
          return (isLoopback(origin.hostname) ? this.direct : this.proxied).dispatch(opts, handler);
        }
        async close() {
          await Promise.all([this.proxied.close(), this.direct.close()]);
        }
        async destroy(err) {
          await Promise.all([this.proxied.destroy(err), this.direct.destroy(err)]);
        }
      }
      LoopbackAwareProxyAgent.__loopbackAware = true;
      undici.ProxyAgent = LoopbackAwareProxyAgent;
    }
  }
} catch (_) {
  // firebase-tools not resolvable from this process (e.g. the mocha child): nothing to do.
}
