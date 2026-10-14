'use strict';
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { getEnv, resetData, staff, outsider, anon } = require('./env');

const MB10 = 10 * 1024 * 1024;
const STAMP = 1760342400000;
const DOC_ID = '0b6c7e1a-5f2d-4b8e-9a31-000000000001';

// Paths exactly as customer_form_screen.dart builds them.
const photoPath = (id, ext = 'jpg') => `customers/${id}/photo_${STAMP}.${ext}`;
const thumbPath = (id) => `customers/${id}/photo_${STAMP}_thumb.jpg`;
const docPath = (id, ext = 'pdf') => `customers/${id}/docs/${DOC_ID}.${ext}`;

// Small but genuine-looking file headers.
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 0xff, 0xd9]);
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
const PDF = new Uint8Array(Buffer.from('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n'));
const WEBP = new Uint8Array(Buffer.from('RIFF\x1a\x00\x00\x00WEBPVP8 '));

const storage = async (ctxPromise) => (await ctxPromise).storage();

/** Upload like FirebaseFileStore.upload (putData + contentType + cacheControl). */
function upload(st, path, bytes, contentType) {
  const meta = { cacheControl: 'private, max-age=31536000' };
  if (contentType !== undefined) meta.contentType = contentType;
  return st.ref(path).put(bytes, meta);
}

/** Put a file in place with rules off (as if staff had uploaded it earlier). */
async function seedFile(path, bytes = JPEG, contentType = 'image/jpeg') {
  const env = await getEnv();
  await env.withSecurityRulesDisabled((ctx) => upload(ctx.storage(), path, bytes, contentType));
}

describe('Storage rules', function () {
  this.timeout(60000);

  beforeEach(async () => {
    await resetData();
  });

  describe('Staff uploads under customers/{id}/', () => {
    it('staff can upload a JPEG profile photo (photo_<ms>.jpg)', async () => {
      await assertSucceeds(upload(await storage(staff()), photoPath('cust-1'), JPEG, 'image/jpeg'));
    });
    it('staff can upload a PNG profile photo (photo_<ms>.png)', async () => {
      await assertSucceeds(upload(await storage(staff()), photoPath('cust-1', 'png'), PNG, 'image/png'));
    });
    it('staff can upload a WebP profile photo (photo_<ms>.webp)', async () => {
      await assertSucceeds(upload(await storage(staff()), photoPath('cust-1', 'webp'), WEBP, 'image/webp'));
    });
    it('staff can upload a HEIC photo (image/heic, which the picker can return)', async () => {
      await assertSucceeds(upload(await storage(staff()), photoPath('cust-1', 'jpg'), JPEG, 'image/heic'));
    });
    it('staff can upload the 256 px thumbnail (photo_<ms>_thumb.jpg)', async () => {
      await assertSucceeds(upload(await storage(staff()), thumbPath('cust-1'), JPEG, 'image/jpeg'));
    });
    it('staff can upload a PDF proof in the nested docs/ folder', async () => {
      await assertSucceeds(upload(await storage(staff()), docPath('cust-1'), PDF, 'application/pdf'));
    });
    it('staff can upload a JPEG proof in the nested docs/ folder', async () => {
      await assertSucceeds(upload(await storage(staff()), docPath('cust-1', 'jpg'), JPEG, 'image/jpeg'));
    });
    it('staff can replace an existing file with a new image', async () => {
      await seedFile(photoPath('cust-1'));
      await assertSucceeds(upload(await storage(staff()), photoPath('cust-1'), PNG, 'image/png'));
    });
  });

  describe('Upload size limit (10 MB)', () => {
    it('a file of exactly 10 MB (10,485,760 bytes) is accepted', async () => {
      await assertSucceeds(upload(await storage(staff()), docPath('cust-1'), new Uint8Array(MB10), 'application/pdf'));
    });
    it('a file of 10 MB + 1 byte is rejected', async () => {
      await assertFails(upload(await storage(staff()), docPath('cust-1'), new Uint8Array(MB10 + 1), 'application/pdf'));
    });
    it('a 10 MB + 1 byte image is rejected', async () => {
      await assertFails(upload(await storage(staff()), photoPath('cust-1'), new Uint8Array(MB10 + 1), 'image/jpeg'));
    });
  });

  describe('Only images and PDFs may be uploaded', () => {
    it('text/plain is rejected', async () => {
      await assertFails(upload(await storage(staff()), docPath('cust-1', 'txt'), PDF, 'text/plain'));
    });
    it('application/zip is rejected', async () => {
      await assertFails(upload(await storage(staff()), docPath('cust-1', 'zip'), PDF, 'application/zip'));
    });
    it('text/html is rejected', async () => {
      await assertFails(upload(await storage(staff()), docPath('cust-1', 'html'), PDF, 'text/html'));
    });
    it('application/octet-stream is rejected', async () => {
      await assertFails(upload(await storage(staff()), docPath('cust-1', 'bin'), PDF, 'application/octet-stream'));
    });
    it('a file uploaded with no content type is rejected', async () => {
      await assertFails(upload(await storage(staff()), docPath('cust-1', 'bin'), PDF, undefined));
    });
    it('an SVG image (can carry script) is rejected', async () => {
      await assertFails(upload(await storage(staff()), photoPath('cust-1'), PDF, 'image/svg+xml'));
    });
    it('a GIF (not something the app produces) is rejected', async () => {
      await assertFails(upload(await storage(staff()), photoPath('cust-1'), PDF, 'image/gif'));
    });
    it('a lookalike type such as application/pdfx is rejected', async () => {
      await assertFails(upload(await storage(staff()), docPath('cust-1'), PDF, 'application/pdfx'));
    });
    it('changing an existing photo’s content type to text/html is rejected', async () => {
      await seedFile(photoPath('cust-1'));
      await assertFails((await storage(staff())).ref(photoPath('cust-1')).updateMetadata({ contentType: 'text/html' }));
    });
    it('staff can update cache metadata on an existing image', async () => {
      await seedFile(photoPath('cust-1'));
      await assertSucceeds(
        (await storage(staff())).ref(photoPath('cust-1')).updateMetadata({ cacheControl: 'private, max-age=60' }),
      );
    });
  });

  describe('Staff can read and delete customer files', () => {
    beforeEach(async () => {
      await seedFile(photoPath('cust-1'));
      await seedFile(thumbPath('cust-1'));
      await seedFile(docPath('cust-1'), PDF, 'application/pdf');
    });
    it('staff can get a download URL for a photo', async () => {
      await assertSucceeds((await storage(staff())).ref(photoPath('cust-1')).getDownloadURL());
    });
    it('staff can read a PDF proof’s metadata', async () => {
      await assertSucceeds((await storage(staff())).ref(docPath('cust-1')).getMetadata());
    });
    it("staff can list a customer's folder (used when deleting a customer)", async () => {
      await assertSucceeds((await storage(staff())).ref('customers/cust-1').listAll());
      await assertSucceeds((await storage(staff())).ref('customers/cust-1/docs').listAll());
    });
    it('staff can delete a photo', async () => {
      await assertSucceeds((await storage(staff())).ref(photoPath('cust-1')).delete());
    });
    it('staff can delete a document in docs/', async () => {
      await assertSucceeds((await storage(staff())).ref(docPath('cust-1')).delete());
    });
  });

  describe('Accounts not on the staff list are locked out', () => {
    beforeEach(async () => {
      await seedFile(photoPath('cust-1'));
      await seedFile(docPath('cust-1'), PDF, 'application/pdf');
    });
    it('cannot upload a photo', async () => {
      await assertFails(upload(await storage(outsider()), photoPath('cust-1'), JPEG, 'image/jpeg'));
    });
    it('cannot upload a PDF proof', async () => {
      await assertFails(upload(await storage(outsider()), docPath('cust-2'), PDF, 'application/pdf'));
    });
    it('cannot read a photo', async () => {
      await assertFails((await storage(outsider())).ref(photoPath('cust-1')).getDownloadURL());
    });
    it('cannot read a document', async () => {
      await assertFails((await storage(outsider())).ref(docPath('cust-1')).getMetadata());
    });
    it("cannot list a customer's files", async () => {
      await assertFails((await storage(outsider())).ref('customers/cust-1').listAll());
    });
    it('cannot delete a file', async () => {
      await assertFails((await storage(outsider())).ref(photoPath('cust-1')).delete());
    });
  });

  describe('Signed-out visitors are locked out', () => {
    beforeEach(async () => {
      await seedFile(photoPath('cust-1'));
      await seedFile(docPath('cust-1'), PDF, 'application/pdf');
    });
    it('cannot upload a photo', async () => {
      await assertFails(upload(await storage(anon()), photoPath('cust-1'), JPEG, 'image/jpeg'));
    });
    it('cannot upload a PDF proof', async () => {
      await assertFails(upload(await storage(anon()), docPath('cust-1'), PDF, 'application/pdf'));
    });
    it('cannot read a photo', async () => {
      await assertFails((await storage(anon())).ref(photoPath('cust-1')).getDownloadURL());
    });
    it('cannot read a document', async () => {
      await assertFails((await storage(anon())).ref(docPath('cust-1')).getMetadata());
    });
    it("cannot list a customer's files", async () => {
      await assertFails((await storage(anon())).ref('customers/cust-1').listAll());
    });
    it('cannot delete a file', async () => {
      await assertFails((await storage(anon())).ref(photoPath('cust-1')).delete());
    });
  });

  describe('Paths outside customers/ are closed', () => {
    it('staff cannot upload an image at the bucket root', async () => {
      await assertFails(upload(await storage(staff()), 'photo.jpg', JPEG, 'image/jpeg'));
    });
    it('staff cannot upload into another top-level folder', async () => {
      await assertFails(upload(await storage(staff()), 'public/photo.jpg', JPEG, 'image/jpeg'));
      await assertFails(upload(await storage(staff()), 'staff/staff-ravi/avatar.png', PNG, 'image/png'));
    });
    it('staff cannot upload a file named like the customers folder', async () => {
      await assertFails(upload(await storage(staff()), 'customers.jpg', JPEG, 'image/jpeg'));
    });
    it('staff cannot read or delete files outside customers/', async () => {
      await seedFile('backups/export.jpg');
      const st = await storage(staff());
      await assertFails(st.ref('backups/export.jpg').getDownloadURL());
      await assertFails(st.ref('backups/export.jpg').delete());
      await assertFails(st.ref('backups').listAll());
    });
    it('non-staff and signed-out visitors cannot list the top-level customers/ folder', async () => {
      await seedFile(photoPath('cust-1'));
      await assertFails((await storage(outsider())).ref('customers').listAll());
      await assertFails((await storage(anon())).ref('customers').listAll());
    });
  });
});
