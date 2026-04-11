#!/usr/bin/env node
/**
 * sync-sd-problems.js
 *
 * Upserts all system design problem JSON files from systemdesign/problems/
 * into the Firestore `sd_problems` collection.
 *
 * Local usage:
 *   node scripts/sync-sd-problems.js
 *   (requires scripts/serviceAccountKey.json — gitignored)
 *
 * CI usage (GitHub Actions):
 *   Set the FIREBASE_SERVICE_ACCOUNT secret to the service account JSON string.
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');

// Credential: CI reads from env var; local reads from file
const credential = process.env.FIREBASE_SERVICE_ACCOUNT
  ? admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT))
  : admin.credential.cert(require('./serviceAccountKey.json'));

admin.initializeApp({ credential });

const db         = admin.firestore();
const problemsDir = path.join(__dirname, '../systemdesign/problems');

async function sync() {
  const files = fs.readdirSync(problemsDir).filter(f => f.endsWith('.json'));

  if (files.length === 0) {
    console.log('No problem JSON files found in systemdesign/problems/');
    process.exit(0);
  }

  let synced = 0;
  for (const file of files) {
    const filePath = path.join(problemsDir, file);
    let problem;
    try {
      problem = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (err) {
      console.error(`✗ Failed to parse ${file}: ${err.message}`);
      continue;
    }

    if (!problem.id) {
      console.error(`✗ Skipping ${file}: missing required "id" field`);
      continue;
    }

    // Firestore doesn't support arrays-of-arrays.
    // Flatten requiredConnections from [["A","B"],["B","C"]] → ["A→B","B→C"]
    if (problem.levels) {
      problem.levels = problem.levels.map(level => ({
        ...level,
        requiredConnections: (level.requiredConnections || []).map(pair => pair.join('→')),
        alternativeSolutions: (level.alternativeSolutions || []).map(alt => ({
          ...alt,
          connections: (alt.connections || []).map(pair => pair.join('→'))
        }))
      }));
    }

    try {
      await db.collection('sd_problems').doc(problem.id).set(problem);
      console.log(`✓ ${problem.id} — ${problem.title} (${problem.levels?.length ?? 0} levels)`);
      synced++;
    } catch (err) {
      console.error(`✗ Failed to upsert ${problem.id}: ${err.message}`);
    }
  }

  console.log(`\nDone. ${synced}/${files.length} problems synced to Firestore.`);
}

sync().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
