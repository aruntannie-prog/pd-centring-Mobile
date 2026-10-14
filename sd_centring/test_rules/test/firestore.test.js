'use strict';
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { getEnv, resetData, staff, outsider, anon, STAFF_UID, OTHER_STAFF_UID, OUTSIDER_UID } = require('./env');
const P = require('./payloads');

/** Puts a document in place with rules off (as if the app had saved it earlier). */
async function seed(path, data) {
  const env = await getEnv();
  await env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc(path).set(data));
}

const db = async (ctxPromise) => (await ctxPromise).firestore();

describe('Firestore rules', function () {
  this.timeout(20000);

  beforeEach(async () => {
    await resetData();
    await seed('customers/cust-1', P.fullCustomer('cust-1'));
    await seed('rentals/rent-1', P.fullRental());
  });

  // ── Who can get in ──────────────────────────────────────────────────────

  describe('Signed-out visitors are locked out', () => {
    it('cannot read a customer', async () => {
      await assertFails((await db(anon())).doc('customers/cust-1').get());
    });
    it('cannot list customers', async () => {
      await assertFails((await db(anon())).collection('customers').get());
    });
    it('cannot create a customer', async () => {
      await assertFails((await db(anon())).doc('customers/new').set(P.fullCustomer('new')));
    });
    it('cannot delete a customer', async () => {
      await assertFails((await db(anon())).doc('customers/cust-1').delete());
    });
    it('cannot read a delivery (rental)', async () => {
      await assertFails((await db(anon())).doc('rentals/rent-1').get());
    });
    it('cannot list deliveries', async () => {
      await assertFails((await db(anon())).collection('rentals').get());
    });
    it('cannot create a delivery', async () => {
      await assertFails((await db(anon())).doc('rentals/new').set(P.fullRental()));
    });
    it('cannot read a staff entry', async () => {
      await assertFails((await db(anon())).doc(`staff/${STAFF_UID}`).get());
    });
    it('cannot add itself to the staff list', async () => {
      await assertFails((await db(anon())).doc('staff/anyone').set({ name: 'x' }));
    });
  });

  describe('Signed-in accounts not on the staff list are locked out', () => {
    it('cannot read a customer', async () => {
      await assertFails((await db(outsider())).doc('customers/cust-1').get());
    });
    it('cannot list customers', async () => {
      await assertFails((await db(outsider())).collection('customers').get());
    });
    it('cannot create a valid customer', async () => {
      await assertFails((await db(outsider())).doc('customers/new').set(P.fullCustomer('new')));
    });
    it('cannot update a customer', async () => {
      await assertFails((await db(outsider())).doc('customers/cust-1').update({ name: 'Hacked' }));
    });
    it('cannot delete a customer', async () => {
      await assertFails((await db(outsider())).doc('customers/cust-1').delete());
    });
    it('cannot read or list deliveries', async () => {
      const d = await db(outsider());
      await assertFails(d.doc('rentals/rent-1').get());
      await assertFails(d.collection('rentals').get());
    });
    it('cannot create, update or delete a delivery', async () => {
      const d = await db(outsider());
      await assertFails(d.doc('rentals/new').set(P.fullRental()));
      await assertFails(d.doc('rentals/rent-1').update({ notes: 'x' }));
      await assertFails(d.doc('rentals/rent-1').delete());
    });
    it('cannot promote itself by creating its own staff entry', async () => {
      await assertFails((await db(outsider())).doc(`staff/${OUTSIDER_UID}`).set({ name: 'me' }));
    });
    it('can check its own (missing) staff entry, which the app uses to explain the lock-out', async () => {
      await assertSucceeds((await db(outsider())).doc(`staff/${OUTSIDER_UID}`).get());
    });
  });

  describe('Staff access', () => {
    it('staff can read a customer', async () => {
      await assertSucceeds((await db(staff())).doc('customers/cust-1').get());
    });
    it('staff can list all customers (the app watches the whole collection)', async () => {
      await assertSucceeds((await db(staff())).collection('customers').get());
    });
    it('staff can read a delivery', async () => {
      await assertSucceeds((await db(staff())).doc('rentals/rent-1').get());
    });
    it('staff can list all deliveries', async () => {
      await assertSucceeds((await db(staff())).collection('rentals').get());
    });
    it('staff can delete a customer', async () => {
      await assertSucceeds((await db(staff())).doc('customers/cust-1').delete());
    });
    it('staff can delete a delivery', async () => {
      await assertSucceeds((await db(staff())).doc('rentals/rent-1').delete());
    });
    it('a second staff member has the same access', async () => {
      const d = await db(staff(OTHER_STAFF_UID));
      await assertSucceeds(d.doc('customers/cust-1').get());
      await assertSucceeds(d.doc('customers/cust-2').set(P.minimalCustomer()));
    });
    it('access ends as soon as the owner removes the staff entry', async () => {
      const env = await getEnv();
      await env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc(`staff/${STAFF_UID}`).delete());
      const d = await db(staff());
      await assertFails(d.doc('customers/cust-1').get());
      await assertFails(d.doc('customers/cust-2').set(P.minimalCustomer()));
    });
  });

  // ── Staff list ──────────────────────────────────────────────────────────

  describe('Staff list (staff/{uid})', () => {
    it('staff can read their own staff entry', async () => {
      await assertSucceeds((await db(staff())).doc(`staff/${STAFF_UID}`).get());
    });
    it("staff cannot read another staff member's entry", async () => {
      await assertFails((await db(staff())).doc(`staff/${OTHER_STAFF_UID}`).get());
    });
    it('staff cannot list the staff collection', async () => {
      await assertFails((await db(staff())).collection('staff').get());
    });
    it('staff cannot edit their own staff entry', async () => {
      await assertFails((await db(staff())).doc(`staff/${STAFF_UID}`).set({ name: 'Ravi', role: 'owner' }));
      await assertFails((await db(staff())).doc(`staff/${STAFF_UID}`).update({ role: 'owner' }));
    });
    it('staff cannot delete their own staff entry', async () => {
      await assertFails((await db(staff())).doc(`staff/${STAFF_UID}`).delete());
    });
    it('staff cannot add a new staff member', async () => {
      await assertFails((await db(staff())).doc(`staff/${OUTSIDER_UID}`).set({ name: 'friend' }));
    });
    it('staff cannot remove another staff member', async () => {
      await assertFails((await db(staff())).doc(`staff/${OTHER_STAFF_UID}`).delete());
    });
  });

  // ── Customer record validation ─────────────────────────────────────────

  describe('Customer records (create)', () => {
    const save = async (data, id = 'cust-new') => (await db(staff())).doc(`customers/${id}`).set(data);

    it('a full customer exactly as Customer.toMap writes it is accepted', async () => {
      await assertSucceeds(save(P.fullCustomer('cust-new')));
    });
    it('a customer with only name, phone and empty optional fields is accepted', async () => {
      await assertSucceeds(save(P.minimalCustomer()));
    });
    it('a customer with only name, phone and createdAt (optional fields absent) is accepted', async () => {
      await assertSucceeds(save({ name: 'Selvi', phone: '9840012345', createdAt: P.NOW }));
    });
    it('a 400-character name is accepted', async () => {
      await assertSucceeds(save(P.minimalCustomer({ name: 'a'.repeat(400) })));
    });
    it('a 1-character name is accepted', async () => {
      await assertSucceeds(save(P.minimalCustomer({ name: 'R' })));
    });
    it('an empty name is rejected', async () => {
      await assertFails(save(P.minimalCustomer({ name: '' })));
    });
    it('a 401-character name is rejected', async () => {
      await assertFails(save(P.minimalCustomer({ name: 'a'.repeat(401) })));
    });
    it('a missing name is rejected', async () => {
      await assertFails(save(P.without(P.minimalCustomer(), 'name')));
    });
    it('a number as name is rejected', async () => {
      await assertFails(save(P.minimalCustomer({ name: 12345 })));
    });
    it('a 10-character phone is accepted', async () => {
      await assertSucceeds(save(P.minimalCustomer({ phone: '9840012345' })));
    });
    it('a 16-character phone is accepted', async () => {
      await assertSucceeds(save(P.minimalCustomer({ phone: '+91 (984) 001234' })));
    });
    it('a 9-character phone is rejected', async () => {
      await assertFails(save(P.minimalCustomer({ phone: '984001234' })));
    });
    it('a 17-character phone is rejected', async () => {
      await assertFails(save(P.minimalCustomer({ phone: '+91 98400 1234567' })));
    });
    it('a missing phone is rejected', async () => {
      await assertFails(save(P.without(P.minimalCustomer(), 'phone')));
    });
    it('a phone stored as a number is rejected', async () => {
      await assertFails(save(P.minimalCustomer({ phone: 9840012345 })));
    });
    it('alternate phone: 16 characters accepted, 17 rejected, non-string rejected', async () => {
      await assertSucceeds(save(P.minimalCustomer({ altPhone: '1'.repeat(16) })));
      await assertFails(save(P.minimalCustomer({ altPhone: '1'.repeat(17) })));
      await assertFails(save(P.minimalCustomer({ altPhone: 9840012345 })));
    });
    it('address: 4000 characters accepted, 4001 rejected, non-string rejected', async () => {
      await assertSucceeds(save(P.minimalCustomer({ address: 'x'.repeat(4000) })));
      await assertFails(save(P.minimalCustomer({ address: 'x'.repeat(4001) })));
      await assertFails(save(P.minimalCustomer({ address: ['12', 'Anna Nagar'] })));
    });
    it('notes: 8000 characters accepted, 8001 rejected, non-string rejected', async () => {
      await assertSucceeds(save(P.minimalCustomer({ notes: 'n'.repeat(8000) })));
      await assertFails(save(P.minimalCustomer({ notes: 'n'.repeat(8001) })));
      await assertFails(save(P.minimalCustomer({ notes: { text: 'hi' } })));
    });
    it('photo URL: 2048 characters accepted, 2049 rejected, non-string rejected', async () => {
      await assertSucceeds(save(P.minimalCustomer({ photoUrl: 'h'.repeat(2048) })));
      await assertFails(save(P.minimalCustomer({ photoUrl: 'h'.repeat(2049) })));
      await assertFails(save(P.minimalCustomer({ photoUrl: true })));
    });
    it('photo thumbnail URL: 2048 characters accepted, 2049 rejected, non-string rejected', async () => {
      await assertSucceeds(save(P.minimalCustomer({ photoThumbUrl: 'h'.repeat(2048) })));
      await assertFails(save(P.minimalCustomer({ photoThumbUrl: 'h'.repeat(2049) })));
      await assertFails(save(P.minimalCustomer({ photoThumbUrl: 42 })));
    });
    it('a base64 photo embedded in the record (old PD app style) is rejected', async () => {
      const base64 = 'data:image/jpeg;base64,' + 'A'.repeat(50000);
      await assertFails(save(P.minimalCustomer({ photoUrl: base64 })));
    });
    it('30 documents are accepted', async () => {
      const docs = Array.from({ length: 30 }, (_, i) => P.customerDoc('cust-new', i));
      await assertSucceeds(save(P.minimalCustomer({ documents: docs })));
    });
    it('31 documents are rejected', async () => {
      const docs = Array.from({ length: 31 }, (_, i) => P.customerDoc('cust-new', i));
      await assertFails(save(P.minimalCustomer({ documents: docs })));
    });
    it('documents that are not a list are rejected', async () => {
      await assertFails(save(P.minimalCustomer({ documents: P.customerDoc('cust-new', 0) })));
      await assertFails(save(P.minimalCustomer({ documents: 'aadhaar.pdf' })));
    });
    it('a missing createdAt is rejected', async () => {
      await assertFails(save(P.without(P.minimalCustomer(), 'createdAt')));
    });
    it('createdAt as a fractional number (double) is rejected', async () => {
      await assertFails(save(P.minimalCustomer({ createdAt: P.NOW + 0.5 })));
    });
    it('createdAt as a Firestore timestamp is rejected (app stores milliseconds)', async () => {
      await assertFails(save(P.minimalCustomer({ createdAt: new Date(P.NOW) })));
    });
    it('createdAt as a string is rejected', async () => {
      await assertFails(save(P.minimalCustomer({ createdAt: '2025-10-13' })));
    });
  });

  describe('Customer records (update)', () => {
    const ref = async () => (await db(staff())).doc('customers/cust-1');

    it('staff can re-save an edited customer (set over an existing record)', async () => {
      await assertSucceeds((await ref()).set(P.fullCustomer('cust-1', { notes: 'Moved to Porur site' })));
    });
    it('staff can update a single field with valid data', async () => {
      await assertSucceeds((await ref()).update({ phone: '9876543210' }));
    });
    it('an update that empties the name is rejected', async () => {
      await assertFails((await ref()).update({ name: '' }));
    });
    it('an update that makes the phone too short is rejected', async () => {
      await assertFails((await ref()).update({ phone: '12345' }));
    });
    it('an update that removes createdAt is rejected', async () => {
      await assertFails((await ref()).set(P.without(P.fullCustomer('cust-1'), 'createdAt')));
    });
    it('an update that pushes documents past 30 is rejected', async () => {
      const docs = Array.from({ length: 31 }, (_, i) => P.customerDoc('cust-1', i));
      await assertFails((await ref()).update({ documents: docs }));
    });
  });

  // ── Delivery (rental) validation ───────────────────────────────────────

  describe('Delivery records (rentals)', () => {
    const save = async (data, id = 'rent-new') => (await db(staff())).doc(`rentals/${id}`).set(data);

    it('a full delivery exactly as Rental.toMap writes it is accepted', async () => {
      await assertSucceeds(save(P.fullRental()));
    });
    it('a new delivery with no returns yet (empty list) is accepted', async () => {
      await assertSucceeds(save(P.fullRental({ returns: [], expiryHistory: [] })));
    });
    it('a delivery that expires on the day it is issued is accepted', async () => {
      await assertSucceeds(save(P.fullRental({ issuedOn: '2026-10-01', expiresOn: '2026-10-01' })));
    });
    it('a delivery that expires before it is issued is rejected', async () => {
      await assertFails(save(P.fullRental({ issuedOn: '2026-10-01', expiresOn: '2026-09-30' })));
    });
    it('an empty DC number is rejected', async () => {
      await assertFails(save(P.fullRental({ dcNumber: '' })));
    });
    it('a missing DC number is rejected', async () => {
      await assertFails(save(P.without(P.fullRental(), 'dcNumber')));
    });
    it('a numeric DC number is rejected', async () => {
      await assertFails(save(P.fullRental({ dcNumber: 142 })));
    });
    it('a missing customerId is rejected', async () => {
      await assertFails(save(P.without(P.fullRental(), 'customerId')));
    });
    it('a non-string customerId is rejected', async () => {
      await assertFails(save(P.fullRental({ customerId: 17 })));
    });
    it('an issue date not in yyyy-MM-dd form is rejected', async () => {
      await assertFails(save(P.fullRental({ issuedOn: '01-10-2026' })));
      await assertFails(save(P.fullRental({ issuedOn: '2026-10-1' })));
      await assertFails(save(P.fullRental({ issuedOn: '2026-10-01T00:00:00' })));
    });
    it('an expiry date not in yyyy-MM-dd form is rejected', async () => {
      await assertFails(save(P.fullRental({ expiresOn: '31/10/2026' })));
    });
    it('dates stored as Firestore timestamps are rejected', async () => {
      await assertFails(save(P.fullRental({ issuedOn: new Date('2026-10-01') })));
      await assertFails(save(P.fullRental({ expiresOn: new Date('2026-10-31') })));
    });
    it('missing issue or expiry dates are rejected', async () => {
      await assertFails(save(P.without(P.fullRental(), 'issuedOn')));
      await assertFails(save(P.without(P.fullRental(), 'expiresOn')));
    });
    it('a delivery with no items is rejected', async () => {
      await assertFails(save(P.fullRental({ items: [] })));
    });
    it('items that are not a list are rejected', async () => {
      await assertFails(save(P.fullRental({ items: { id: 'it-1', name: 'Prop', qty: 1 } })));
      await assertFails(save(P.fullRental({ items: JSON.stringify([{ id: 'it-1' }]) })));
    });
    it('missing items are rejected', async () => {
      await assertFails(save(P.without(P.fullRental(), 'items')));
    });
    it('returns that are not a list are rejected', async () => {
      await assertFails(save(P.fullRental({ returns: 'none' })));
    });
    it('missing returns are rejected', async () => {
      await assertFails(save(P.without(P.fullRental(), 'returns')));
    });
    it('staff can record a return by re-saving the delivery', async () => {
      const r = P.fullRental();
      r.returns = [...r.returns, { id: 'rt-2', itemId: 'it-2', qty: 40.5, date: '2026-10-12', note: '' }];
      await assertSucceeds(save(r, 'rent-1'));
    });
    it('staff can extend the expiry date', async () => {
      await assertSucceeds((await db(staff())).doc('rentals/rent-1').update({ expiresOn: '2026-11-15' }));
    });
    it('an update that moves expiry before the issue date is rejected', async () => {
      await assertFails((await db(staff())).doc('rentals/rent-1').update({ expiresOn: '2026-09-01' }));
    });
  });

  // ── Everything else ─────────────────────────────────────────────────────

  describe('Any other collection is closed', () => {
    it('staff cannot read or write an unknown top-level collection', async () => {
      const d = await db(staff());
      await assertFails(d.doc('settings/app').get());
      await assertFails(d.doc('settings/app').set({ theme: 'dark' }));
      await assertFails(d.collection('settings').get());
    });
    it('staff cannot write a subcollection under a customer', async () => {
      const d = await db(staff());
      await assertFails(d.doc('customers/cust-1/photos/p1').set({ data: 'x' }));
      await assertFails(d.doc('customers/cust-1/photos/p1').get());
    });
    it('staff cannot write a subcollection under a delivery', async () => {
      await assertFails((await db(staff())).doc('rentals/rent-1/log/1').set({ at: 1 }));
    });
    it('signed-out visitors cannot write an unknown collection', async () => {
      await assertFails((await db(anon())).doc('public/hello').set({ a: 1 }));
    });
  });
});
