'use strict';
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
const { getEnv } = require('./env');

// Denied writes are expected in these tests; keep the SDK from logging each one.
firebase.firestore.setLogLevel('silent');

exports.mochaHooks = {
  async afterAll() {
    const env = await getEnv();
    await env.cleanup();
  },
};
