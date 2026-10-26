// Run with `npm test` (starts the Firestore emulator against ../firestore.rules).
import { readFileSync } from 'node:fs';
import { after, beforeEach, before, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, Timestamp, updateDoc, writeBatch } from 'firebase/firestore';

const HOUR = 60 * 60 * 1000;
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-gooddeeds',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());

// Organizers A and B, volunteers V and W; A owns an event that started 1h ago with V joined.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/orgA'), { role: 'Organizer', organizerApproved: true });
    await setDoc(doc(db, 'users/orgB'), { role: 'Organizer', organizerApproved: true });
    await setDoc(doc(db, 'users/newOrg'), { role: 'Organizer' });
    await setDoc(doc(db, 'users/vol'), { role: 'Volunteer', impactPoints: 10, totalPoints: 10, rewardPoints: 10, points: 10 });
    await setDoc(doc(db, 'users/vol2'), { role: 'Volunteer' });
    await setDoc(doc(db, 'events/e1'), eventData(Date.now() - HOUR));
    await setDoc(doc(db, 'events/old'), eventData(Date.now() - 72 * HOUR));
  });
});

function eventData(startMs, extra = {}) {
  return {
    title: 'Beach cleanup',
    createdByUid: 'orgA',
    impactPoints: 50,
    eventDate: Timestamp.fromMillis(startMs),
    participantIds: ['vol', 'orgA'],
    participantsCount: 2,
    checkedInIds: [],
    awardedParticipantIds: [],
    ...extra,
  };
}

const as = (uid) => env.authenticatedContext(uid).firestore();
const points = (n) => ({ impactPoints: n, totalPoints: n, rewardPoints: n, points: n });

// Mirrors participants_screen.dart _setCheckedIn.
function checkIn(db, eventId, uid, newPoints) {
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}`), {
    ...points(newPoints),
    attendanceEventId: eventId,
    participationStatusByEvent: { [eventId]: 'attended' },
    updatedAt: Timestamp.now(),
  }, { merge: true });
  batch.update(doc(db, `events/${eventId}`), {
    checkedInIds: [uid],
    awardedParticipantIds: [uid],
    updatedAt: Timestamp.now(),
  });
  return batch.commit();
}

test('owner organizer can check in a joined volunteer and award event points', async () => {
  await assertSucceeds(checkIn(as('orgA'), 'e1', 'vol', 60));
});

test('another organizer cannot edit or check in on someone else\'s event', async () => {
  await assertFails(updateDoc(doc(as('orgB'), 'events/e1'), { title: 'hijacked' }));
  await assertFails(checkIn(as('orgB'), 'e1', 'vol', 60));
});

test('owner can still edit their own event details', async () => {
  await assertSucceeds(updateDoc(doc(as('orgA'), 'events/e1'), { title: 'New title' }));
});

test('points must match the event award exactly', async () => {
  await assertFails(checkIn(as('orgA'), 'e1', 'vol', 500));
});

test('check-in is rejected after the 48-hour window', async () => {
  await assertFails(checkIn(as('orgA'), 'old', 'vol', 60));
});

test('organizer cannot award points to someone who never joined', async () => {
  const db = as('orgA');
  const batch = writeBatch(db);
  batch.set(doc(db, 'users/vol2'), { ...points(50), attendanceEventId: 'e1', updatedAt: Timestamp.now() }, { merge: true });
  batch.update(doc(db, 'events/e1'), { awardedParticipantIds: ['vol2'], updatedAt: Timestamp.now() });
  await assertFails(batch.commit());
});

test('organizer cannot check in or award themselves', async () => {
  await assertFails(checkIn(as('orgA'), 'e1', 'orgA', 50));
});

test('volunteer cannot check themselves in or raise their own points', async () => {
  await assertFails(updateDoc(doc(as('vol'), 'events/e1'), { checkedInIds: ['vol'] }));
  await assertFails(updateDoc(doc(as('vol'), 'users/vol'), points(999)));
});

test('volunteer can join only as themselves', async () => {
  await assertSucceeds(updateDoc(doc(as('vol2'), 'events/e1'), {
    participantIds: ['vol', 'orgA', 'vol2'], participantsCount: 3,
  }));
  await assertFails(updateDoc(doc(as('vol2'), 'events/e1'), {
    participantIds: ['orgA'], participantsCount: 1,
  }));
});

test('volunteer can leave after check-in, reversing their own points', async () => {
  await checkIn(as('orgA'), 'e1', 'vol', 60);
  const db = as('vol');
  const batch = writeBatch(db);
  batch.set(doc(db, 'users/vol'), { ...points(10), updatedAt: Timestamp.now() }, { merge: true });
  batch.update(doc(db, 'events/e1'), {
    participantIds: ['orgA'], participantsCount: 1, checkedInIds: [], awardedParticipantIds: [],
  });
  await assertSucceeds(batch.commit());
});

test('event points are frozen once someone is awarded', async () => {
  await checkIn(as('orgA'), 'e1', 'vol', 60);
  await assertFails(updateDoc(doc(as('orgA'), 'events/e1'), { impactPoints: 200 }));
});

test('unapproved organizer cannot create events or approve themselves', async () => {
  const db = as('newOrg');
  await assertFails(setDoc(doc(db, 'events/e5'), eventData(Date.now(), { createdByUid: 'newOrg' })));
  await assertFails(updateDoc(doc(db, 'users/newOrg'), { organizerApproved: true }));
  await assertFails(setDoc(doc(as('fresh'), 'users/fresh'), { role: 'Organizer', organizerApproved: true }));
  await assertSucceeds(updateDoc(doc(db, 'users/newOrg'), { name: 'New Org' }));
});

test('organizer cannot create an event owned by someone else or with out-of-range points', async () => {
  await assertFails(setDoc(doc(as('orgA'), 'events/e2'), eventData(Date.now(), { createdByUid: 'orgB' })));
  await assertFails(setDoc(doc(as('orgA'), 'events/e3'), eventData(Date.now(), { impactPoints: 5000 })));
  await assertSucceeds(setDoc(doc(as('orgA'), 'events/e4'), eventData(Date.now())));
});
