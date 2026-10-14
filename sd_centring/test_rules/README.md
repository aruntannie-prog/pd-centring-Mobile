# Security-rules tests

Automated checks for `../firestore.rules` and `../storage.rules`, run against
the Firebase Local Emulator Suite with `@firebase/rules-unit-testing` and mocha.
Nothing here touches a real Firebase project: the project id is
`demo-sd-centring` (the `demo-` prefix means emulator-only).

## Requirements

- Node 18+ (tested with Node 22) and npm
- Java 11+ (the emulators are Java; tested with Java 21)
- Network access the first time, so firebase-tools can download the emulator
  jars into `~/.cache/firebase/emulators`

## Run

```sh
cd sd_centring/test_rules
npm install
npm run test:emulators
```

That starts the Firestore and Storage emulators (ports 8080 and 9199, set in
`../firebase.json` under `emulators`), runs `npm test` (mocha) against them,
and shuts them down. Exit code 0 means every test passed.

To keep emulators running while you edit tests, start them in one terminal and
run `npm test` in another:

```sh
npx firebase emulators:start --config ../firebase.json --only firestore,storage --project demo-sd-centring
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 npm test
```

Both emulators must run together: `storage.rules` checks the staff list with
`firestore.exists(...)`, which the Storage emulator answers by asking the
Firestore emulator.

## What is covered

| File | Covers |
| --- | --- |
| `test/firestore.test.js` | signed-out and non-staff lock-out; staff read/list/write/delete; the `staff/{uid}` list (read own only, never writable); customer and delivery (rental) validation; every other path closed |
| `test/storage.test.js` | staff uploads at the app's real paths (`photo_<ms>.<ext>`, `photo_<ms>_thumb.jpg`, `docs/<uuid>.<ext>`); the 10 MB limit (exactly 10 MB passes, 10 MB + 1 byte fails); image/PDF only; non-staff and signed-out lock-out; staff read/list/delete; paths outside `customers/` closed |
| `test/payloads.js` | records built the way `Customer.toMap()` and `Rental.toMap()` write them |
| `test/env.js` | emulator connection, staff list seeding, user contexts |

Tests load the rules files directly from the app folder. To confirm the tests
catch a broken rule, point them at an edited copy (never edit the real file):

```sh
FIRESTORE_RULES=/tmp/broken/firestore.rules STORAGE_RULES=/tmp/broken/storage.rules npm run test:emulators
```

## Behind an HTTP(S) proxy

firebase-tools sends all its requests through `HTTPS_PROXY` and ignores
`NO_PROXY`, including the Storage emulator's own call to the Firestore emulator
for `firestore.exists()`. Behind a proxy that call fails quietly, so every
staff check in `storage.rules` acts as "not staff" and the staff storage tests
fail with `storage/unauthorized`.

`npm run test:emulators` therefore preloads `scripts/loopback-no-proxy.cjs`,
which sends only loopback addresses (localhost, 127.x, ::1) directly and leaves
everything else on the proxy. Without a proxy it does nothing. The script uses
POSIX `NODE_OPTIONS=...` syntax; on Windows, run the `firebase emulators:exec`
command from `package.json` yourself (set `NODE_OPTIONS` first only if you are
behind a proxy).
