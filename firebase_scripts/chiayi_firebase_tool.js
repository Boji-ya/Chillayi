#!/usr/bin/env node
/**
 * chiayi_firebase_tool.js
 * ─────────────────────────────────────────────────────────────────────────────
 * 用途：從 seed_data.json 重建 Firebase，或把 Firebase 現有資料備份成 JSON
 *
 * 使用方式：
 *   node chiayi_firebase_tool.js upload    ← 把 JSON 上傳到 Firebase（完整重置）
 *   node chiayi_firebase_tool.js backup    ← 把 Firebase 現有資料備份成 JSON 檔
 *   node chiayi_firebase_tool.js restore   ← 從備份 JSON 還原（不刪現有資料）
 *
 * 環境需求：
 *   npm install firebase-admin
 *   在 Firebase Console → 專案設定 → 服務帳戶 → 下載 serviceAccountKey.json
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ── 設定區 ─────────────────────────────────────────────────────────────────
const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'serviceAccountKey.json');
const SEED_DATA_PATH       = path.join(__dirname, 'data', 'seed_data.json');
const BACKUP_DIR           = path.join(__dirname, 'backups');

// 要操作的 collections（按順序）
const COLLECTIONS = ['places', 'restaurants', 'hotels', 'events', 'transport_stops', 'missions', 'shops'];
// ────────────────────────────────────────────────────────────────────────────

// 初始化 Firebase Admin
function initFirebase() {
  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ 找不到 serviceAccountKey.json，請放在：${SERVICE_ACCOUNT_PATH}`);
    console.error('   Firebase Console → 專案設定 → 服務帳戶 → 產生新的私密金鑰');
    process.exit(1);
  }
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  return admin.firestore();
}

// 工具：批次寫入（Firestore 每批最多 500 筆）
async function batchWrite(db, collectionName, docs) {
  const CHUNK = 400;
  let written = 0;
  for (let i = 0; i < docs.length; i += CHUNK) {
    const batch = db.batch();
    const chunk = docs.slice(i, i + CHUNK);
    for (const doc of chunk) {
      batch.set(db.collection(collectionName).doc(), doc);
    }
    await batch.commit();
    written += chunk.length;
  }
  return written;
}

// 工具：批次刪除
async function batchDelete(db, collectionName) {
  const snap = await db.collection(collectionName).get();
  if (snap.empty) return 0;
  const CHUNK = 400;
  let deleted = 0;
  const docs = snap.docs;
  for (let i = 0; i < docs.length; i += CHUNK) {
    const batch = db.batch();
    docs.slice(i, i + CHUNK).forEach(d => batch.delete(d.ref));
    await batch.commit();
    deleted += Math.min(CHUNK, docs.length - i);
  }
  return deleted;
}

// ── 指令 1：upload（從 JSON 完整重置 Firebase）──────────────────────────────
async function upload() {
  console.log('\n🚀 開始上傳資料到 Firebase...\n');

  if (!fs.existsSync(SEED_DATA_PATH)) {
    console.error(`❌ 找不到資料檔：${SEED_DATA_PATH}`);
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(SEED_DATA_PATH, 'utf8'));
  const db = initFirebase();

  let totalWritten = 0;
  for (const col of COLLECTIONS) {
    const items = data[col];
    if (!items || items.length === 0) {
      console.log(`  ⏭  ${col}：無資料，跳過`);
      continue;
    }

    process.stdout.write(`  🗑  刪除舊的 ${col}...`);
    const deleted = await batchDelete(db, col);
    process.stdout.write(` (${deleted} 筆)\n`);

    process.stdout.write(`  ✍  寫入 ${col}...`);
    const written = await batchWrite(db, col, items);
    process.stdout.write(` ✅ ${written} 筆\n`);

    totalWritten += written;
  }

  console.log(`\n🎉 完成！共上傳 ${totalWritten} 筆資料到 Firebase。`);
  console.log(`   上傳者：透過 serviceAccountKey.json（服務帳戶身分識別）\n`);
}

// ── 指令 2：backup（把 Firebase 現有資料備份成帶時間戳的 JSON）───────────────
async function backup() {
  console.log('\n💾 開始備份 Firebase 資料...\n');

  const db = initFirebase();
  const result = {};
  let totalDocs = 0;

  for (const col of COLLECTIONS) {
    process.stdout.write(`  📥 讀取 ${col}...`);
    const snap = await db.collection(col).get();
    result[col] = snap.docs.map(d => ({ _id: d.id, ...d.data() }));
    process.stdout.write(` ${result[col].length} 筆\n`);
    totalDocs += result[col].length;
  }

  // 建立備份目錄
  if (!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR, { recursive: true });

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const backupFile = path.join(BACKUP_DIR, `backup_${timestamp}.json`);
  fs.writeFileSync(backupFile, JSON.stringify(result, null, 2), 'utf8');

  console.log(`\n✅ 備份完成！共 ${totalDocs} 筆文件`);
  console.log(`   檔案儲存於：${backupFile}\n`);
}

// ── 指令 3：restore（從備份 JSON 還原，不刪除 Firebase 現有資料）─────────────
async function restore(backupFile) {
  // 若沒指定檔案，自動選最新備份
  if (!backupFile) {
    if (!fs.existsSync(BACKUP_DIR)) {
      console.error('❌ 找不到 backups/ 目錄，請先執行 backup');
      process.exit(1);
    }
    const files = fs.readdirSync(BACKUP_DIR)
      .filter(f => f.endsWith('.json'))
      .sort()
      .reverse();
    if (files.length === 0) {
      console.error('❌ backups/ 目錄內沒有備份檔');
      process.exit(1);
    }
    backupFile = path.join(BACKUP_DIR, files[0]);
    console.log(`\n📂 自動選用最新備份：${files[0]}`);
  }

  console.log(`\n♻️  開始從備份還原：${backupFile}\n`);

  if (!fs.existsSync(backupFile)) {
    console.error(`❌ 找不到備份檔：${backupFile}`);
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(backupFile, 'utf8'));
  const db = initFirebase();

  let totalWritten = 0;
  for (const col of COLLECTIONS) {
    const items = data[col];
    if (!items || items.length === 0) continue;

    // 還原時保留原本的 Firestore document ID（如果有 _id 欄位）
    const batch = db.batch();
    let count = 0;
    for (const item of items) {
      const { _id, ...fields } = item;
      const ref = _id
        ? db.collection(col).doc(_id)
        : db.collection(col).doc();
      batch.set(ref, fields, { merge: true }); // merge 避免覆蓋手動新增欄位
      count++;
    }
    await batch.commit();
    console.log(`  ✅ ${col}：還原 ${count} 筆`);
    totalWritten += count;
  }

  console.log(`\n🎉 還原完成！共寫入 ${totalWritten} 筆資料。\n`);
}

// ── 主程式 ──────────────────────────────────────────────────────────────────
async function main() {
  const cmd = process.argv[2];
  const arg = process.argv[3]; // 可選：備份檔路徑

  switch (cmd) {
    case 'upload':
      await upload();
      break;
    case 'backup':
      await backup();
      break;
    case 'restore':
      await restore(arg);
      break;
    default:
      console.log(`
嘉義探索 App - Firebase 資料管理工具
══════════════════════════════════════

  node chiayi_firebase_tool.js upload
    → 從 data/seed_data.json 完整重置 Firebase（刪舊資料後重建）

  node chiayi_firebase_tool.js backup
    → 把 Firebase 現有資料備份成 backups/backup_YYYY-MM-DD.json

  node chiayi_firebase_tool.js restore [備份檔路徑]
    → 從備份 JSON 還原（不指定路徑則自動選最新備份）

使用前請先：
  1. npm install firebase-admin
  2. 把 serviceAccountKey.json 放在此目錄
     (Firebase Console → 專案設定 → 服務帳戶 → 產生新的私密金鑰)
`);
  }

  process.exit(0);
}

main().catch(err => {
  console.error('\n❌ 執行錯誤：', err.message);
  process.exit(1);
});