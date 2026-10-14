# Browser end-to-end checks

Black-box checks of the **built** web app in Chromium with real key presses
and real file choosers (photo and PDF upload), which Flutter's own
integration tests cannot drive in a release build.

```bash
cd sd_centring
flutter build web --no-web-resources-cdn
python3 -m http.server 8765 --directory build/web &
cd e2e_web
npm install && npx playwright install chromium   # or set CHROMIUM=/path/to/chrome
npm test
```

`BASE_URL` overrides the app address. Each suite prints one PASS/FAIL line
per check; `npm test` fails if any check fails or the page logs an error.
