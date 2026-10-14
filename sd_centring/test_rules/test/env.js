'use strict';
// Shared test environment: one Firestore + Storage emulator connection for all
// test files, loaded with the real rules from the app folder.

const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-sd-centring';
const APP_DIR = path.resolve(__dirname, '..', '..');
// FIRESTORE_RULES / STORAGE_RULES may point at other rules files (e.g. to
// check that the tests catch a deliberately broken copy). Default: the app's.

function hostPort(envVar, fallback) {
  const v = process.env[envVar] || fallback;
  const i = v.lastIndexOf(':');
  return { host: v.slice(0, i), port: Number(v.slice(i + 1)) };
}

let envPromise;

function getEnv() {
  if (!envPromise) {
    envPromise = initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        ...hostPort('FIRESTORE_EMULATOR_HOST', '127.0.0.1:8080'),
        rules: fs.readFileSync(process.env.FIRESTORE_RULES || path.join(APP_DIR, 'firestore.rules'), 'utf8'),
      },
      storage: {
        ...hostPort('FIREBASE_STORAGE_EMULATOR_HOST', '127.0.0.1:9199'),
        rules: fs.readFileSync(process.env.STORAGE_RULES || path.join(APP_DIR, 'storage.rules'), 'utf8'),
      },
    });
  }
  return envPromise;
}

// Users used throughout the tests.
const STAFF_UID = 'staff-ravi';
const OTHER_STAFF_UID = 'staff-meena';
const OUTSIDER_UID = 'outsider-xyz'; // signed in, but not on the staff list

/** Clears all data and re-adds the staff list (as the owner would in the console). */
async function resetData() {
  const env = await getEnv();
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`staff/${STAFF_UID}`).set({ name: 'Ravi', addedAt: 1760000000000 });
    await db.doc(`staff/${OTHER_STAFF_UID}`).set({ name: 'Meena', addedAt: 1760000000000 });
  });
}

/** Signed-in staff member. */
async function staff(uid = STAFF_UID) {
  return (await getEnv()).authenticatedContext(uid);
}
/** Signed-in account that is NOT on the staff list. */
async function outsider() {
  return (await getEnv()).authenticatedContext(OUTSIDER_UID);
}
/** Not signed in at all. */
async function anon() {
  return (await getEnv()).unauthenticatedContext();
}

module.exports = {
  getEnv,
  resetData,
  staff,
  outsider,
  anon,
  PROJECT_ID,
  STAFF_UID,
  OTHER_STAFF_UID,
  OUTSIDER_UID,
};
