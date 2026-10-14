'use strict';
// Payloads built exactly like the app writes them:
//   Customer.toMap()  (lib/models/customer.dart)
//   Rental.toMap()    (lib/models/rental.dart)
// Integers stay integers (millisecondsSinceEpoch); qty is a Dart double.

const BUCKET = 'demo-sd-centring.appspot.com';
const NOW = 1760342400000; // 2025-10-13T08:00:00Z, an int like DateTime.millisecondsSinceEpoch

function downloadUrl(objectPath) {
  return (
    `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/` +
    encodeURIComponent(objectPath) +
    '?alt=media&token=6f1c2a7e-3b9d-4c55-9e3e-2b8f0f4d1a77'
  );
}

/** CustomerDoc.toMap() */
function customerDoc(customerId, i = 0, overrides = {}) {
  const id = `0b6c7e1a-5f2d-4b8e-9a31-${String(i).padStart(12, '0')}`;
  return {
    id,
    kind: 'Aadhaar',
    fileName: `aadhaar_front_${i}.pdf`,
    url: downloadUrl(`customers/${customerId}/docs/${id}.pdf`),
    contentType: 'application/pdf',
    sizeBytes: 482113,
    uploadedAt: NOW + i,
    ...overrides,
  };
}

/** A full Customer.toMap() with a photo, thumbnail and two documents. */
function fullCustomer(customerId = 'cust-1', overrides = {}) {
  return {
    name: 'Ravi Kumar',
    // The form saves normalizePhone(): digits with an optional leading '+'.
    phone: '+919840012345',
    altPhone: '04426261234',
    address: '12, 3rd Cross Street, Anna Nagar West, Chennai 600040',
    notes: 'Site at Mogappair. Call before delivery.',
    photoUrl: downloadUrl(`customers/${customerId}/photo_${NOW}.jpg`),
    photoThumbUrl: downloadUrl(`customers/${customerId}/photo_${NOW}_thumb.jpg`),
    documents: [
      customerDoc(customerId, 1),
      customerDoc(customerId, 2, {
        kind: 'Utility bill',
        fileName: 'eb_bill.jpg',
        contentType: 'image/jpeg',
        url: downloadUrl(`customers/${customerId}/docs/x.jpg`),
      }),
    ],
    createdAt: NOW,
    ...overrides,
  };
}

/** A minimal Customer.toMap(): optional fields are empty strings / empty list. */
function minimalCustomer(overrides = {}) {
  return {
    name: 'Selvi',
    phone: '9840012345',
    altPhone: '',
    address: '',
    notes: '',
    photoUrl: '',
    photoThumbUrl: '',
    documents: [],
    createdAt: NOW,
    ...overrides,
  };
}

/** A full Rental.toMap() with items, a partial return and an expiry change. */
function fullRental(overrides = {}) {
  return {
    dcNumber: 'DC-0142',
    customerId: 'cust-1',
    customerName: 'Ravi Kumar',
    site: 'Mogappair, plot 44',
    issuedOn: '2026-10-01',
    expiresOn: '2026-10-31',
    items: [
      { id: 'it-1', name: 'Centring sheet 3x2', qty: 120.0, unit: 'pcs' },
      { id: 'it-2', name: 'Prop 3m', qty: 40.5, unit: 'pcs' },
    ],
    returns: [{ id: 'rt-1', itemId: 'it-1', qty: 20.0, date: '2026-10-10', note: 'partial' }],
    expiryHistory: [{ from: '2026-10-20', to: '2026-10-31', changedAt: NOW }],
    notes: '',
    closed: false,
    lastMessagedAt: null,
    createdAt: NOW,
    updatedAt: NOW,
    ...overrides,
  };
}

/** Removes a field, like an older/other client that never wrote it. */
function without(obj, key) {
  const copy = { ...obj };
  delete copy[key];
  return copy;
}

module.exports = { NOW, BUCKET, downloadUrl, customerDoc, fullCustomer, minimalCustomer, fullRental, without };
