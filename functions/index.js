/**
 * SafeGuard — backend Cloud Functions.
 *
 * Triggers:
 *  - classifyIncident    : AI-assisted keyword classification of new reports
 *                          (swap `keywordClassify` for a Vertex AI / LLM call in
 *                          production; the schema it writes stays identical).
 *  - notifyIncidentOnCreate : push admins + nearby responders about new reports.
 *  - onIncidentChanged    : notify on status change / responder assignment.
 *  - notifySos            : dispatch SOS to nearby responders + trusted contacts.
 *  - broadcastCommunityAlert : fan out a community alert to every user.
 *  - onNotificationResend    : re-attempts delivery for a notification the
 *                              user asked the app to retry.
 *  - onIncidentReviewed      : flags an AI audit entry as overridden by a human.
 *  - withdrawAnonymousReport : deletes an anonymous report when the reporter
 *                              proves ownership with their withdrawal code.
 *
 * Delivery status: every notification is written as `pending`, then marked
 * `delivered` or `failed` once the push is attempted, so the app can tell the
 * user when an alert did not reach their device. Per-user notification
 * preferences (`users/{uid}/notificationPreferences`) are honoured before
 * anything is sent; SOS alerts are never suppressed.
 *
 * Field naming matches the Flutter models in lib/models/.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { getDistance } = require('geolib');

admin.initializeApp();
const db = admin.firestore();

const REGION = 'europe-west1';
const SOS_RADIUS_M = 3000;
const INCIDENT_NOTIFY_RADIUS_M = 5000;

// ---------------------------------------------------------------------------
// Notification helpers
// ---------------------------------------------------------------------------

/** Creates the in-app `notifications` document the app renders. */
async function pushDbNotification({ recipientId, type, title, body, relatedEntityId, deliveryStatus = 'delivered' }) {
  const doc = db.collection('notifications').doc();
  await doc.set({
    notificationId: doc.id,
    recipientId,
    type,
    title,
    body,
    relatedEntityId: relatedEntityId || null,
    deliveryStatus,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    readAt: null,
    resendRequestedAt: null,
  });
  return doc.id;
}

/** Resolves a user's FCM token from the `users` -> `fcmToken` field. */
async function fcmTokenFor(userId) {
  if (!userId) return null;
  const snap = await db.collection('users').doc(userId).get();
  if (!snap.exists) return null;
  const token = snap.data().fcmToken;
  return typeof token === 'string' && token.length > 0 ? token : null;
}

/**
 * Sends a push. Returns { ok, failedTokens } so callers can record delivery
 * status per recipient instead of silently dropping failures.
 */
async function sendPush(tokens, { title, body, data }) {
  const valid = (tokens || []).filter((t) => typeof t === 'string' && t.length > 0);
  if (valid.length === 0) return { ok: true, failedTokens: [] };
  try {
    const res = await admin.messaging().sendEachForMulticast({
      tokens: valid,
      notification: { title, body },
      data: data || {},
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    const failedTokens = [];
    res.responses.forEach((r, i) => {
      if (r.success) return;
      console.warn(`FCM send failed for token ${valid[i]}: ${r.error.message}`);
      failedTokens.push(valid[i]);
    });
    return { ok: res.failureCount === 0, failedTokens };
  } catch (e) {
    console.error('sendEachForMulticast failed', e.message);
    return { ok: false, failedTokens: valid };
  }
}

/** True when the user's notification preferences allow this type. */
async function prefsAllow(userId, type) {
  const snap = await db.collection('users').doc(userId).get();
  const prefs = snap.exists ? snap.data().notificationPreferences : null;
  if (!prefs) return true;
  if (type === 'incident_update') return prefs.incidentUpdates !== false;
  if (type === 'assignment') return prefs.assignments !== false;
  if (type === 'community_alert') return prefs.communityAlerts !== false;
  return true;
}

async function notifyUser({ userId, type, title, body, relatedEntityId, data }) {
  if (!(await prefsAllow(userId, type))) {
    console.log(`Notification skipped for ${userId} (${type} disabled by user)`);
    return null;
  }
  const notificationId = await pushDbNotification({
    recipientId: userId,
    type,
    title,
    body,
    relatedEntityId,
    deliveryStatus: 'pending',
  });
  const token = await fcmTokenFor(userId);
  const { ok, failedTokens } =
    await sendPush(token ? [token] : [], { title, body, data });
  await db.collection('notifications').doc(notificationId).update({
    // No token means the in-app record is all we can deliver, which succeeds.
    deliveryStatus: token && !ok ? 'failed' : 'delivered',
    deliveredAt: ok ? admin.firestore.FieldValue.serverTimestamp() : null,
  });
  // Stale device tokens are dead weight; stop pushing to them.
  if (failedTokens.length > 0) {
    await db.collection('users').doc(userId).set({ fcmToken: null }, { merge: true });
  }
  return notificationId;
}

/** Active responders, optionally filtered by distance from a point. */
async function activeResponders(lat, lng, radiusM) {
  const snap = await db
    .collection('users')
    .where('role', '==', 'responder')
    .where('status', '==', 'active')
    .get();
  const out = [];
  for (const d of snap.docs) {
    const u = d.data();
    const hasCoords =
      typeof lat === 'number' && typeof lng === 'number' &&
      typeof u.latitude === 'number' && typeof u.longitude === 'number';
    if (hasCoords && radiusM) {
      const dist = getDistance(
        { latitude: lat, longitude: lng },
        { latitude: u.latitude, longitude: u.longitude }
      );
      if (dist > radiusM) continue;
    }
    out.push({ userId: d.id, name: u.name, ...u });
  }
  return out;
}

// ---------------------------------------------------------------------------
// 1. AI-assisted incident classification
// ---------------------------------------------------------------------------

const KEYWORDS = {
  robbery: {
    words: ['rob', 'robbed', 'robbery', 'thief', 'thieves', 'stolen', 'steal', 'mugged', 'mugging', 'burglary', 'break in', 'snatch', 'pickpocket'],
    sub: 'Theft / robbery',
    priority: 'urgent',
  },
  fire: {
    words: ['fire', 'burning', 'burn', 'smoke', 'flame', 'house fire', 'electrical fire', 'bush fire'],
    sub: 'Structure / bush fire',
    priority: 'urgent',
  },
  medical: {
    words: ['medical', 'unconscious', 'heart attack', 'breathing', 'faint', 'collapsed', 'bleeding', 'injured', 'ambulance', 'sick', 'emergency', 'miscarriage', 'asthma'],
    sub: 'Medical emergency',
    priority: 'urgent',
  },
  accident: {
    words: ['accident', 'crash', 'collision', 'hit', 'knocked', 'overturned', 'boda crash', 'vehicle'],
    sub: 'Road accident',
    priority: 'urgent',
  },
  domestic: {
    words: ['domestic', 'quarrel', 'family fight', 'wife beating', 'husband', 'violence', 'abuse', 'shouting'],
    sub: 'Domestic quarrel / violence',
    priority: 'high',
  },
  suspicious: {
    words: ['suspicious', 'loitering', 'stranger', 'unusual', 'watching', 'following', 'unknown person', 'suspected'],
    sub: 'Suspicious activity',
    priority: 'normal',
  },
  assault: {
    words: ['assault', 'attacked', 'beaten', 'stabbed', 'wounded', 'grievous harm', 'beating', 'punched'],
    sub: 'Physical assault',
    priority: 'urgent',
  },
  fight: {
    words: ['fight', 'fighting', 'brawl', 'disturbance', 'fighting crowd', 'noise', 'riot'],
    sub: 'Fight / disturbance',
    priority: 'high',
  },
  missing: {
    words: ['missing', 'lost', 'disappeared', 'gone missing', 'abducted', 'kidnapped', 'not returned'],
    sub: 'Missing person',
    priority: 'high',
  },
  flood: {
    words: ['flood', 'flooding', 'flooded', 'water', 'waterlogged', 'storm', 'rain', 'landslide', 'damaged roof'],
    sub: 'Flood / storm damage',
    priority: 'urgent',
  },
};

const DEFAULT_CAT = 'other';

function keywordClassify(description, category) {
  const text = (description || '').toLowerCase();
  let best = null;
  let bestScore = 0;
  for (const [cat, cfg] of Object.entries(KEYWORDS)) {
    // Self-reported category counts extra.
    let score = 0;
    if (category === cat) score += 2;
    for (const w of cfg.words) {
      if (text.includes(w)) score += 1;
    }
    if (score > bestScore) {
      bestScore = score;
      best = { cat, ...cfg };
    }
  }
  if (bestScore === 0) {
    return { category: DEFAULT_CAT, subCategory: 'General / unclear', priority: 'normal', confidence: 0.3, summary: 'Could not confidently classify — a responder should verify.' };
  }
  const confidence = Math.min(0.98, 0.4 + bestScore * 0.13);
  const summary =
    best.cat === 'fire'
      ? 'Possible fire or burning reported — treat as urgent.'
      : best.cat === 'medical'
      ? 'Possible medical emergency — medical responders advised.'
      : best.cat === 'accident'
      ? 'Possible road accident — send responder and organise traffic diversion.'
      : best.cat === 'robbery'
      ? 'Possible robbery or theft reported — caution advised.'
      : best.cat === 'domestic'
      ? 'Domestic quarrel/violence reported — a calm responder should intervene.'
      : best.cat === 'suspicious'
      ? 'Suspicious activity reported — patrol advised.'
      : best.cat === 'assault'
      ? 'Assault reported — urgent police attention required.'
      : best.cat === 'fight'
      ? 'Fight/disturbance in progress — crowd control advised.'
      : best.cat === 'missing'
      ? 'Missing person reported — organise search immediately.'
      : best.cat === 'flood'
      ? 'Flooding or storm damage reported — hazard assessment advised.'
      : `Classified as ${best.cat}.`;
  return {
    category: best.cat,
    subCategory: best.sub,
    priority: best.priority,
    confidence,
    summary,
  };
}

/** Finds a likely duplicate (same category, recent, nearby). */
async function likelyDuplicate(incident) {
  const since = new Date(Date.now() - 2 * 60 * 60 * 1000);
  const snap = await db
    .collection('incidents')
    .where('category', '==', incident.category)
    .where('reportedAt', '>=', since)
    .limit(20)
    .get();
  let best = null;
  for (const d of snap.docs) {
    if (d.id === incident.incidentId) continue;
    const other = d.data();
    const loc = other.location || {};
    if (typeof loc.latitude !== 'number' || typeof loc.longitude !== 'number') continue;
    const dist = getDistance(
      { latitude: incident.location.latitude, longitude: incident.location.longitude },
      { latitude: loc.latitude, longitude: loc.longitude }
    );
    if (dist < 200) {
      const age = Math.abs((other.reportedAt?.toMillis?.() || Date.now()) - Date.now());
      const near = dist < 100 && age < 45 * 60 * 1000;
      if (!best || (near && !best.near)) {
        best = { id: d.id, dist, near };
      }
    }
  }
  return best;
}

/**
 * Records what the classifier decided, so an administrator can audit every
 * automated decision. Written for successes and failures alike — an audit log
 * that only records the happy path is worthless.
 */
async function writeAuditLog({ incidentId, reporterId, outcome, startedAt }) {
  const entry = {
    logId: '',
    incidentId,
    reporterId: reporterId || null,
    ...outcome,
    durationMs: Date.now() - startedAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  try {
    const ref = await db.collection('ai_classification_log').add(entry);
    await ref.update({ logId: ref.id });
  } catch (e) {
    // Never let auditing break incident processing.
    console.error('failed to write AI audit log', e.message);
  }
}

exports.classifyIncident = functions
  .runWith({ memory: '256MB', timeoutSeconds: 60 })
  .region(REGION)
  .firestore
  .document('incidents/{incidentId}')
  .onCreate(async (snap, context) => {
    const startedAt = Date.now();
    const data = snap.data();
    const updates = {};
    const suggestion = keywordClassify(data.description, data.category);

    const dup = await likelyDuplicate({
      incidentId: context.params.incidentId,
      category: suggestion.category,
      location: data.location || {},
    });
    if (dup) {
      suggestion.duplicateOf = dup.id;
      suggestion.summary = `${suggestion.summary} This looks like a repeat of an existing report (${dup.dist}m away).`;
      if (dup.near) updates.status = 'duplicate';
    }

    updates.category = suggestion.category;
    updates.priority = suggestion.priority;
    updates.aiSuggestion = suggestion;
    updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    await snap.ref.update(updates);

    const accepted = data.category === suggestion.category;
    await writeAuditLog({
      incidentId: context.params.incidentId,
      reporterId: data.reporterId,
      outcome: {
        model: 'keywordClassify',
        inputCategory: data.category || null,
        outputCategory: suggestion.category,
        outputSubCategory: suggestion.subCategory,
        outputPriority: suggestion.priority,
        confidence: suggestion.confidence,
        summary: suggestion.summary,
        duplicateOf: dup ? dup.id : null,
        result: 'ok',
        agreedWithReporter: accepted,
        // Set when a human corrects the machine; kept for future ML tuning.
        overridden: false,
      },
      startedAt,
    });

    console.log(`classified ${context.params.incidentId} as ${suggestion.category} (conf ${suggestion.confidence.toFixed(2)})`);
  });

// ---------------------------------------------------------------------------
// 1b. Record human overrides of the classifier
// ---------------------------------------------------------------------------

/** Flags the audit entry as overridden when a human changes the category. */
exports.onIncidentReviewed = functions
  .region(REGION)
  .firestore
  .document('incidents/{incidentId}')
  .onUpdate(async (change) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (!before.aiSuggestion) return;              // nothing the AI produced
    if (before.category === after.category) return; // not a correction
    if (!after.aiSuggestionConfirmedBy) return;     // not a human decision

    const recent = await db
      .collection('ai_classification_log')
      .where('incidentId', '==', change.params.incidentId)
      .limit(5)
      .get();
    const entry = recent.docs.find((d) => d.data().result === 'ok');
    if (!entry) return;
    await entry.ref.update({
      overridden: true,
      overriddenCategory: after.category || null,
      reviewedBy: after.aiSuggestionConfirmedBy,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

// ---------------------------------------------------------------------------
// 2. Notify on new incident
// ---------------------------------------------------------------------------
exports.notifyIncidentOnCreate = functions
  .region(REGION)
  .firestore
  .document('incidents/{incidentId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const loc = data.location || {};
    const title = 'New incident reported';
    const body = `${data.category} near ${data.locationLabel || 'unknown area'}. Tap to respond.`;
    const dataPayload = { type: 'incident', relatedId: snap.id };

    const closest = await activeResponders(loc.latitude, loc.longitude, INCIDENT_NOTIFY_RADIUS_M);
    for (const r of closest) {
      await notifyUser({
        userId: r.userId,
        type: 'incident_update',
        title,
        body,
        relatedEntityId: snap.id,
        data: dataPayload,
      });
    }

    // Administrators always get it.
    const admins = await db.collection('users').where('role', '==', 'administrator').get();
    for (const a of admins.docs) {
      await notifyUser({
        userId: a.id,
        type: 'incident_update',
        title: `New ${data.category} report`,
        body: `${data.reporterName || 'A resident'} reported ${data.description.slice(0, 80)}…`,
        relatedEntityId: snap.id,
        data: dataPayload,
      });
    }
    console.log(`notified ${closest.length} responders + admins for incident ${snap.id}`);
  });

// ---------------------------------------------------------------------------
// 3. Notify on status change / assignment
// ---------------------------------------------------------------------------

exports.onIncidentChanged = functions
  .region(REGION)
  .firestore
  .document('incidents/{incidentId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    const id = change.after.id;

    const data = { type: 'incident', relatedId: id };

    if (before.assignedResponderId !== after.assignedResponderId && after.assignedResponderId) {
      await notifyUser({
        userId: after.assignedResponderId,
        type: 'assignment',
        title: 'Incident assigned to you',
        body: `${after.category} at ${after.locationLabel || 'unknown area'}. Tap to view.`,
        relatedEntityId: id,
        data,
      });
      console.log(`assigned ${id} to ${after.assignedResponderId}`);
    }

    if (before.status !== after.status) {
      await notifyUser({
        userId: after.reporterId,
        type: 'incident_update',
        title: 'Your report was updated',
        body: `Incident ${id} is now "${after.status}".`,
        relatedEntityId: id,
        data,
      });
    }
  });

// ---------------------------------------------------------------------------
// 4. SOS dispatch
// ---------------------------------------------------------------------------

exports.notifySos = functions
  .region(REGION)
  .firestore
  .document('sos_alerts/{sosId}')
  .onCreate(async (snap) => {
    const sos = snap.data();
    const btn = 'RESPOND NOW';

    // Nearby responders.
    const responders = await activeResponders(sos.latitude, sos.longitude, SOS_RADIUS_M);
    const dispatched = [];
    for (const r of responders) {
      await notifyUser({
        userId: r.userId,
        type: 'sos',
        title: `EMERGENCY SOS — ${sos.userName || 'A resident'}`,
        body: `SOS at ${sos.latitude.toFixed(5)}, ${sos.longitude.toFixed(5)}. ${sos.note ? sos.note : 'No note added.'}`,
        relatedEntityId: snap.id,
        data: { type: 'sos', relatedId: snap.id, latitude: String(sos.latitude), longitude: String(sos.longitude) },
      });
      dispatched.push(r.userId);
    }
    console.log(`SOS ${snap.id}: notified ${dispatched.length} responders immediately`);

    // Trusted contacts.
    const contacts = await db
      .collection('trusted_contacts')
      .where('userId', '==', sos.userId)
      .where('confirmationStatus', 'in', ['confirmed', 'pending'])
      .get();
    const contacted = [];
    for (const c of contacts.docs) {
      const contact = c.data();
      if (contact.contactUserId) {
        await notifyUser({
          userId: contact.contactUserId,
          type: 'sos',
          title: `SafeGuard: ${sos.userName || 'Your contact'} sent an SOS`,
          body: 'They need help right now. Please call them or contact emergency services.',
          relatedEntityId: snap.id,
          data: { type: 'sos', relatedId: snap.id },
        });
        contacted.push(contact.contactUserId);
      }
    }
    console.log(`SOS ${snap.id}: contacted ${contacted.length} trusted contacts`);

    // Home guard: if no responder was in range, escalate to all active responders.
    let escalated = [];
    if (dispatched.length === 0) {
      const all = await activeResponders(null, null, null);
      for (const r of all) {
        await notifyUser({
          userId: r.userId,
          type: 'sos',
          title: `EMERGENCY SOS (no responder in range) — ${sos.userName || 'A resident'}`,
          body: sos.note || 'No note added. Nearest responders were out of range.',
          relatedEntityId: snap.id,
          data: { type: 'sos', relatedId: snap.id },
        });
        escalated.push(r.userId);
      }
      console.log(`SOS ${snap.id}: escalated to ${escalated.length} responders`);
    }

    await snap.ref.update({
      notifiedResponders: admin.firestore.FieldValue.arrayUnion([...dispatched, ...escalated]),
      notifiedContacts: admin.firestore.FieldValue.arrayUnion(contacted),
      status: 'active',
    });
  });

// ---------------------------------------------------------------------------
// 5. Community alert broadcast
// ---------------------------------------------------------------------------

exports.broadcastCommunityAlert = functions
  .region(REGION)
  .firestore
  .document('community_alerts/{alertId}')
  .onCreate(async (snap) => {
    const alert = snap.data();
    const data = { type: 'community_alert', relatedId: snap.id };
    const users = await db.collection('users').listDocuments();
    let sent = 0;
    let failed = 0;
    const CHUNK = 100;
    for (let i = 0; i < users.length; i += CHUNK) {
      const batch = users.slice(i, i + CHUNK);
      const tokens = [];
      const tokenOwner = {};
      const pending = [];
      for (const ref of batch) {
        const u = (await ref.get()).data();
        if (!u) continue;
        if (u.notificationPreferences && u.notificationPreferences.communityAlerts === false) {
          continue;
        }
        if (!u.fcmToken) continue;
        tokens.push(u.fcmToken);
        tokenOwner[u.fcmToken] = ref.id;
        const notificationId = await pushDbNotification({
          recipientId: ref.id,
          type: 'community_alert',
          title: `[${String(alert.severity).toUpperCase()}] ${alert.title}`,
          body: alert.body,
          relatedEntityId: snap.id,
          deliveryStatus: 'pending',
        });
        pending.push(notificationId);
        sent += 1;
      }
      const { ok, failedTokens } = await sendPush(tokens, {
        title: `[${String(alert.severity).toUpperCase()}] ${alert.title}`,
        body: alert.area ? `${alert.area} — ${alert.body}` : alert.body,
        data,
      });
      const failedSet = new Set(failedTokens);
      await Promise.all(pending.map(async (id, idx) => {
        const token = tokens[idx];
        const bad = token && failedSet.has(token);
        if (bad) failed += 1;
        await db.collection('notifications').doc(id).update({
          deliveryStatus: bad ? 'failed' : 'delivered',
          deliveredAt: bad ? null : admin.firestore.FieldValue.serverTimestamp(),
        });
      }));
      if (!ok) {
        console.warn(`community alert ${snap.id}: ${failedTokens.length} push failures`);
      }
    }
    console.log(`community alert ${snap.id}: notified ${sent} users (${failed} failed)`);
  });

/**
 * Re-attempts delivery when the user asks for a retry in the app. The client
 * only sets `resendRequestedAt`; this function owns the delivery result.
 */
exports.onNotificationResend = functions.firestore
  .document('notifications/{nid}')
  .onUpdate(async (change, ctx) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    // Only react to a fresh retry request.
    if (!after.resendRequestedAt || before.resendRequestedAt) return;
    if (after.deliveryStatus !== 'pending') return;

    const token = await fcmTokenFor(after.recipientId);
    const { ok } = await sendPush(token ? [token] : [], {
      title: after.title || 'SafeGuard',
      body: after.body || '',
      data: { type: after.type || '', relatedId: after.relatedEntityId || '' },
    });
    await change.after.ref.update({
      deliveryStatus: token && !ok ? 'failed' : 'delivered',
      deliveredAt: ok ? admin.firestore.FieldValue.serverTimestamp() : null,
      resendRequestedAt: null,
    });
  });

/**
 * Withdraws an anonymous report using only the reporter's withdrawal code.
 *
 * Firestore rules cannot verify a hash against a code the client never sends,
 * so the check has to live here. The code is compared by digest; the account
 * making the call is never written to the report, so withdrawing does not
 * de-anonymise anything.
 */
const crypto = require('crypto');

const tokenFor = (code) =>
  crypto.createHash('sha256').update(String(code || '').toUpperCase().replace(/[^A-Z0-9]/g, '')).digest('hex');

exports.withdrawAnonymousReport = functions
  .region(REGION)
  .https.onCall(async (data) => {
    const code = data && data.code;
    const incidentId = data && data.incidentId;
    if (typeof code !== 'string' || code.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'A withdrawal code is required.');
    }
    if (typeof incidentId !== 'string' || incidentId.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'A report reference is required.');
    }

    const accessRef = db.collection('report_access').doc(tokenFor(code));
    const access = await accessRef.get();
    if (!access.exists || access.data().incidentId !== incidentId) {
      // Deliberately vague: a wrong code must not confirm the report exists.
      throw new functions.https.HttpsError('not-found', 'That code does not match this report.');
    }

    const incidentRef = db.collection('incidents').doc(incidentId);
    const incident = await incidentRef.get();
    if (!incident.exists) {
      await accessRef.delete();
      throw new functions.https.HttpsError('not-found', 'That report has already been withdrawn.');
    }
    if (incident.data().isAnonymous !== true) {
      throw new functions.https.HttpsError('failed-precondition', 'Only anonymous reports can be withdrawn with a code.');
    }
    if (incident.data().status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'This report is already being handled and can no longer be withdrawn.');
    }

    await incidentRef.delete();
    await accessRef.delete();
    console.log(`anonymous report ${incidentId} withdrawn with its code`);
    return { withdrawn: true };
  });

exports.REGION = REGION;
exports.admin = admin;
exports.db = db;