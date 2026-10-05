#!/usr/bin/env node

const fs   = require('fs');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'serviceAccountKey.json');
const OUTPUT_PATH          = path.join(__dirname, 'data', 'osm_data.json');
const OVERPASS_URL         = 'https://overpass-api.de/api/interpreter';

// Chiayi City bounding box (south, west, north, east)
const BBOX = '23.43,120.40,23.53,120.50';

// ── OSM tag definitions per your app's categories ────────────────────────────
const CATEGORY_QUERIES = [
  {
    category: 'attraction',
    label: '景點',
    queries: [
      `node["tourism"="attraction"](${BBOX});`,
      `way["tourism"="attraction"](${BBOX});`,
      `node["tourism"="viewpoint"](${BBOX});`,
      `node["historic"](${BBOX});`,
      `way["historic"](${BBOX});`,
    ],
  },
  {
    category: 'attraction_museum',
    label: '博物館',
    queries: [
      `node["tourism"="museum"](${BBOX});`,
      `way["tourism"="museum"](${BBOX});`,
      `node["tourism"="gallery"](${BBOX});`,
    ],
  },
  {
    category: 'attraction_park',
    label: '公園',
    queries: [
      `node["leisure"="park"](${BBOX});`,
      `way["leisure"="park"](${BBOX});`,
      `node["leisure"="garden"](${BBOX});`,
    ],
  },
  {
    category: 'restaurant',
    label: '餐廳',
    queries: [
      `node["amenity"="restaurant"](${BBOX});`,
      `way["amenity"="restaurant"](${BBOX});`,
    ],
  },
  {
    category: 'restaurant_cafe',
    label: '咖啡廳',
    queries: [
      `node["amenity"="cafe"](${BBOX});`,
      `way["amenity"="cafe"](${BBOX});`,
    ],
  },
  {
    category: 'restaurant_dessert',
    label: '甜點',
    queries: [
      `node["amenity"="ice_cream"](${BBOX});`,
      `node["shop"="bakery"](${BBOX});`,
      `node["shop"="confectionery"](${BBOX});`,
    ],
  },
  {
    category: 'hotel',
    label: '旅館',
    queries: [
      `node["tourism"="hotel"](${BBOX});`,
      `way["tourism"="hotel"](${BBOX});`,
    ],
  },
];

// ── Helpers ───────────────────────────────────────────────────────────────────
async function overpassFetch(queryBody, retries = 3) {
  const { default: fetch } = await import('node-fetch');
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(OVERPASS_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `data=${encodeURIComponent(queryBody)}`,
        timeout: 30000,
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (err) {
      if (i === retries - 1) throw err;
      console.log(`    ⚠️  重試 (${i + 1}/${retries})...`);
      await new Promise(r => setTimeout(r, 2000 * (i + 1)));
    }
  }
}

function getCoords(el) {
  if (el.type === 'node') return { lat: el.lat, lng: el.lon };
  if (el.center)          return { lat: el.center.lat, lng: el.center.lon };
  return null;
}

function getName(tags) {
  return tags['name:zh'] || tags['name:zh-TW'] || tags['name'] || null;
}

function getAddress(tags) {
  const parts = [
    tags['addr:city'] || '嘉義市',
    tags['addr:district'] || tags['addr:suburb'] || '',
    tags['addr:street'] || '',
    tags['addr:housenumber'] || '',
  ].filter(Boolean);
  return parts.length > 1 ? parts.join('') : (tags['addr:full'] || '嘉義市');
}

function buildTags(osmTags, categoryLabel) {
  const result = [categoryLabel];
  if (osmTags['cuisine'])       result.push(...osmTags['cuisine'].split(';'));
  if (osmTags['amenity'])       result.push(osmTags['amenity']);
  if (osmTags['tourism'])       result.push(osmTags['tourism']);
  if (osmTags['historic'])      result.push(osmTags['historic']);
  if (osmTags['opening_hours']) result.push('已有營業時間');
  return [...new Set(result)].slice(0, 5);
}

function defaultImage(category) {
  const map = {
    attraction:          'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?w=800',
    attraction_museum:   'https://images.unsplash.com/photo-1518998053901-5348d3961a04?w=800',
    attraction_park:     'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?w=800',
    restaurant:          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
    restaurant_cafe:     'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800',
    restaurant_dessert:  'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800',
    hotel:               'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
  };
  return map[category] || map['attraction'];
}

function initFirebase() {
  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
    });
  }
  return admin.firestore();
}

// ── STEP 1: fetch ─────────────────────────────────────────────────────────────
async function fetchOsmData() {
  console.log('\n🌐 開始從 OpenStreetMap 抓取嘉義地點資料...\n');

  const parentCategory = (cat) => {
    if (cat.startsWith('restaurant')) return 'restaurants';
    if (cat.startsWith('hotel'))      return 'hotels';
    return 'places';
  };

  const result  = { places: [], restaurants: [], hotels: [] };
  const seenIds = new Set();

  for (const { category, label, queries } of CATEGORY_QUERIES) {
    const fullQuery = `[out:json][timeout:25];\n(\n${queries.join('\n')}\n);\nout center;`;
    process.stdout.write(`  📡 抓取 ${label} (${category})...`);

    let elements = [];
    try {
      const data = await overpassFetch(fullQuery);
      elements = data.elements || [];
    } catch (err) {
      console.log(` ❌ 失敗：${err.message}`);
      continue;
    }

    let count = 0;
    for (const el of elements) {
      const tags   = el.tags || {};
      const name   = getName(tags);
      if (!name) continue;

      const coords = getCoords(el);
      if (!coords) continue;

      const osmId = `${el.type}_${el.id}`;
      if (seenIds.has(osmId)) continue;
      seenIds.add(osmId);

      const place = {
        name,
        description:  tags['description'] || tags['note'] || '',
        imageUrl:     defaultImage(category),
        location:     getAddress(tags),
        category,
        rating:       0,
        ratingCount:  0,
        tags:         buildTags(tags, label),
        lat:          coords.lat,
        lng:          coords.lng,
        openingHours: tags['opening_hours'] || '',
        phone:        tags['phone'] || tags['contact:phone'] || '',
        website:      tags['website'] || tags['contact:website'] || '',
        osmId,
      };

      result[parentCategory(category)].push(place);
      count++;
    }

    console.log(` ✅ ${count} 筆`);
    await new Promise(r => setTimeout(r, 1000));
  }

  if (!fs.existsSync(path.dirname(OUTPUT_PATH))) {
    fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
  }
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(result, null, 2), 'utf8');

  const total = Object.values(result).reduce((s, a) => s + a.length, 0);
  console.log(`\n✅ 共抓取 ${total} 筆地點資料`);
  console.log(`   places:      ${result.places.length}`);
  console.log(`   restaurants: ${result.restaurants.length}`);
  console.log(`   hotels:      ${result.hotels.length}`);
  console.log(`\n💾 已儲存到：${OUTPUT_PATH}\n`);

  return result;
}

// ── STEP 2: upload ────────────────────────────────────────────────────────────
async function uploadToFirebase(data) {
  console.log('\n🚀 開始上傳到 Firebase...\n');

  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ 找不到 serviceAccountKey.json：${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
  }

  const db         = initFirebase();
  const COLS       = ['places', 'restaurants', 'hotels'];
  const CHUNK      = 400;
  let totalWritten = 0;

  for (const col of COLS) {
    const items = data[col];
    if (!items || items.length === 0) {
      console.log(`  ⏭  ${col}：無資料，跳過`);
      continue;
    }

    process.stdout.write(`  🔍 檢查 ${col} 重複資料...`);
    const snap           = await db.collection(col).get();
    const existingOsmIds = new Set(snap.docs.map(d => d.data().osmId).filter(Boolean));
    const existingNames  = new Set(snap.docs.map(d => d.data().name).filter(Boolean));
    process.stdout.write(` (現有 ${snap.docs.length} 筆)\n`);

    const newItems = items.filter(item => {
      if (item.osmId && existingOsmIds.has(item.osmId)) return false;
      if (item.name  && existingNames.has(item.name))   return false;
      return true;
    });

    if (newItems.length === 0) {
      console.log(`  ✅ ${col}：無新資料需要新增`);
      continue;
    }

    process.stdout.write(`  ✍  寫入 ${col} (${newItems.length} 筆新資料)...`);
    let written = 0;
    for (let i = 0; i < newItems.length; i += CHUNK) {
      const batch = db.batch();
      newItems.slice(i, i + CHUNK).forEach(doc => batch.set(db.collection(col).doc(), doc));
      await batch.commit();
      written += Math.min(CHUNK, newItems.length - i);
    }
    console.log(` ✅ ${written} 筆`);
    totalWritten += written;
  }

  console.log(`\n🎉 完成！共上傳 ${totalWritten} 筆地點到 Firebase。\n`);
}

// ── STEP 3: enrich (Google Places API → ratings only) ────────────────────────
async function enrichWithGooglePlaces(apiKey) {
  console.log('\n⭐ 開始用 Google Places API 補齊評分...\n');

  if (!apiKey) {
    console.error('❌ 請提供 Google Places API Key：');
    console.error('   node chiayi_osm_seeder.js enrich YOUR_API_KEY');
    process.exit(1);
  }

  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ 找不到 serviceAccountKey.json：${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
  }

  const { default: fetch } = await import('node-fetch');
  const db = initFirebase();

  // Only update places_test and restaurants_test
  const COLLECTIONS = ['places_test', 'restaurants_test', 'hotels_test'];
  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalFailed  = 0;

  for (const col of COLLECTIONS) {
    console.log(`\n📂 處理 ${col}...`);
    const snap = await db.collection(col).get();
    if (snap.empty) { console.log('   (空的，跳過)'); continue; }

    for (const doc of snap.docs) {
      const data = doc.data();

      // Skip if already enriched
      if (data.googleEnriched) { totalSkipped++; continue; }

      const name = data.name;
      const lat  = data.lat;
      const lng  = data.lng;
      if (!name || lat == null || lng == null) { totalSkipped++; continue; }

      // ── 1. Find Place ID by name + coordinates ───────────────────────────
      let placeId = null;
      try {
        const findUrl = `https://maps.googleapis.com/maps/api/place/findplacefromtext/json`
          + `?input=${encodeURIComponent(name)}`
          + `&inputtype=textquery`
          + `&locationbias=point:${lat},${lng}`
          + `&fields=place_id`
          + `&language=zh-TW`
          + `&key=${apiKey}`;

        const findRes  = await fetch(findUrl);
        const findData = await findRes.json();
        if (findData.candidates && findData.candidates.length > 0) {
          placeId = findData.candidates[0].place_id;
        }
      } catch (e) {
        totalFailed++;
        continue;
      }

      if (!placeId) {
        process.stdout.write(`  ⚠️  找不到：${name}\n`);
        totalSkipped++;
        await new Promise(r => setTimeout(r, 200));
        continue;
      }

      // ── 2. Get rating from Place Details ────────────────────────────────
      let rating           = null;
      let userRatingsTotal = 0;

      try {
        const detailUrl = `https://maps.googleapis.com/maps/api/place/details/json`
          + `?place_id=${placeId}`
          + `&fields=rating,user_ratings_total`
          + `&key=${apiKey}`;

        const detailRes  = await fetch(detailUrl);
        const detailData = await detailRes.json();
        const result     = detailData.result || {};

        rating           = result.rating             || null;
        userRatingsTotal = result.user_ratings_total || 0;
      } catch (e) {
        totalFailed++;
        continue;
      }

      // ── 3. Update Firestore ──────────────────────────────────────────────
      const update = { googleEnriched: true };
      if (rating)           update.rating      = rating;
      if (userRatingsTotal) update.ratingCount = userRatingsTotal;

      await doc.ref.update(update);
      totalUpdated++;
      process.stdout.write(
        `  ✅ ${name.padEnd(20)} rating: ${rating ?? '-'} (${userRatingsTotal} 則評論)\n`
      );

      // Stay within Google's QPS limit
      await new Promise(r => setTimeout(r, 200));
    }
  }

  console.log(`\n🎉 完成！`);
  console.log(`   更新：${totalUpdated} 筆`);
  console.log(`   跳過：${totalSkipped} 筆（已處理過或無座標）`);
  console.log(`   失敗：${totalFailed} 筆`);
  console.log(`\n💡 再次執行時已處理過的地點會自動跳過（googleEnriched: true）\n`);
}

// ── STEP 4: describe (Claude API → Chinese descriptions) ─────────────────────
async function generateDescriptions() {
  console.log('\n🤖 開始用 Claude API 生成中文簡介...\n');

  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ 找不到 serviceAccountKey.json：${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
  }

  const { default: fetch } = await import('node-fetch');
  const db = initFirebase();

  const catLabel = {
    attraction:          '景點',
    attraction_nature:   '自然風景景點',
    attraction_culture:  '文化古蹟',
    attraction_temple:   '廟宇寺院',
    attraction_park:     '公園',
    attraction_museum:   '博物館',
    restaurant:          '餐廳',
    restaurant_cafe:     '咖啡廳',
    restaurant_dessert:  '甜點店',
    hotel:               '旅館',
  };

  const COLLECTIONS = ['places', 'restaurants', 'hotels'];
  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalFailed  = 0;

  for (const col of COLLECTIONS) {
    console.log(`\n📂 處理 ${col}...`);
    const snap = await db.collection(col).get();
    if (snap.empty) { console.log('   (空的，跳過)'); continue; }

    for (const doc of snap.docs) {
      const data = doc.data();

      if (data.description && data.description.trim().length > 10) {
        totalSkipped++;
        continue;
      }

      const name     = data.name;
      const category = data.category || '';
      const location = data.location || '嘉義市';
      if (!name) { totalSkipped++; continue; }

      const typeLabel = catLabel[category] || '地點';
      let description = null;

      try {
        const prompt =
          `你是嘉義在地旅遊達人。請為以下地點寫一段繁體中文簡介，約50-80字。\n` +
          `地點名稱：${name}\n` +
          `類型：${typeLabel}\n` +
          `地址：${location}\n\n` +
          `規則：\n` +
          `- 如果你不確定這個地點的真實資訊，請只回覆「UNKNOWN」，不要編造內容\n` +
          `- 如果你知道這個地點，請寫出真實的特色、亮點或推薦原因\n` +
          `- 語氣親切自然，像在地人介紹給朋友\n` +
          `- 只輸出簡介文字，不要加任何標題或說明`;

        const res = await fetch('https://api.anthropic.com/v1/messages', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': process.env.ANTHROPIC_API_KEY || '',
            'anthropic-version': '2023-06-01',
          },
          body: JSON.stringify({
            model: 'claude-haiku-4-5-20251001',
            max_tokens: 200,
            messages: [{ role: 'user', content: prompt }],
          }),
        });

        const resData = await res.json();
        const text    = resData.content?.[0]?.text?.trim();
        if (text && !text.includes('UNKNOWN')) description = text;
      } catch (e) {
        totalFailed++;
        continue;
      }

      if (!description) {
        process.stdout.write(`  ⚠️  跳過（不確定）：${name}\n`);
        totalSkipped++;
        await new Promise(r => setTimeout(r, 100));
        continue;
      }

      await doc.ref.update({ description, claudeDescription: true });
      totalUpdated++;
      process.stdout.write(`  ✅ ${name.padEnd(20)} → ${description.slice(0, 30)}...\n`);
      await new Promise(r => setTimeout(r, 200));
    }
  }

  console.log(`\n🎉 完成！`);
  console.log(`   生成：${totalUpdated} 筆`);
  console.log(`   跳過：${totalSkipped} 筆`);
  console.log(`   失敗：${totalFailed} 筆`);
  console.log(`\n💡 需先設定環境變數：`);
  console.log(`   Windows: set ANTHROPIC_API_KEY=your_key`);
  console.log(`   Mac/Linux: export ANTHROPIC_API_KEY=your_key\n`);
}

// ── STEP 5: taiwan-tourism ────────────────────────────────────────────────────
async function fetchTaiwanTourism() {
  console.log('\n🏛️  從交通部觀光署官方資料庫抓取嘉義景點資訊...\n');

  const { default: fetch } = await import('node-fetch');
  const db = initFirebase();

  const TOURISM_URLS = {
    attraction: 'https://media.taiwan.net.tw/XMLReleaseALL_public/scenic_spot_C_f.json',
    restaurant: 'https://media.taiwan.net.tw/XMLReleaseALL_public/restaurant_C_f.json',
    hotel:      'https://media.taiwan.net.tw/XMLReleaseALL_public/hotel_C_f.json',
  };

  let totalUpdated = 0;

  for (const [type, url] of Object.entries(TOURISM_URLS)) {
    process.stdout.write(`  📥 下載${type}資料...`);
    let items = [];
    try {
      const res  = await fetch(url);
      const data = await res.json();
      items = (data.XML_Head?.Infos?.Info || []).filter(item =>
        item.Region === '嘉義市' || item.Add?.includes('嘉義市')
      );
      console.log(` ${items.length} 筆嘉義資料`);
    } catch (e) {
      console.log(` ❌ 失敗：${e.message}`);
      continue;
    }

    const col  = type === 'attraction' ? 'places' : type === 'restaurant' ? 'restaurants' : 'hotels';
    const snap = await db.collection(col).get();

    for (const item of items) {
      const tourismName = item.Name?.trim();
      if (!tourismName) continue;

      const match = snap.docs.find(doc => {
        const docName = doc.data().name?.trim();
        if (!docName) return false;
        if (docName === tourismName) return true;
        if (docName.includes(tourismName) || tourismName.includes(docName)) return true;
        if (docName.length >= 2 && tourismName.startsWith(docName.slice(0, 2))) return true;
        return false;
      });

      if (!match) {
        if (item.Px && item.Py) {
          const descText = item.Toldescribe || item.Description || '';
          await db.collection(col).doc().set({
            name:                  tourismName,
            description:           descText.trim(),
            imageUrl:              item.Picture1 || defaultImage(type),
            location:              item.Add || '嘉義市',
            category:              type === 'attraction' ? 'attraction' : type === 'restaurant' ? 'restaurant' : 'hotel',
            rating:                0,
            ratingCount:           0,
            tags:                  [],
            lat:                   parseFloat(item.Py),
            lng:                   parseFloat(item.Px),
            phone:                 item.Tel || '',
            openingHours:          item.Opentime || '',
            taiwanTourismEnriched: true,
          });
          totalUpdated++;
          process.stdout.write(`  ➕ 新增：${tourismName}\n`);
        }
        continue;
      }

      const update  = { taiwanTourismEnriched: true };
      const descText = item.Toldescribe || item.Description || '';
      if (descText && descText.trim().length > 10) update.description  = descText.trim();
      if (item.Picture1 && item.Picture1.trim())   update.imageUrl     = item.Picture1.trim();
      if (item.Py && item.Px) {
        update.lat = parseFloat(item.Py);
        update.lng = parseFloat(item.Px);
      }
      if (item.Tel)      update.phone        = item.Tel;
      if (item.Opentime) update.openingHours = item.Opentime;

      await match.ref.update(update);
      totalUpdated++;
      process.stdout.write(`  ✅ 更新：${tourismName}\n`);
    }
  }

  console.log(`\n🎉 完成！共更新 ${totalUpdated} 筆地點\n`);
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  const cmd    = process.argv[2];
  const apiKey = process.argv[3];

  switch (cmd) {
    case 'fetch':
      await fetchOsmData();
      break;
    case 'upload': {
      if (!fs.existsSync(OUTPUT_PATH)) {
        console.error(`❌ 找不到 ${OUTPUT_PATH}，請先執行 fetch`);
        process.exit(1);
      }
      const data = JSON.parse(fs.readFileSync(OUTPUT_PATH, 'utf8'));
      await uploadToFirebase(data);
      break;
    }
    case 'all': {
      const data = await fetchOsmData();
      await uploadToFirebase(data);
      break;
    }
    case 'enrich':
      await enrichWithGooglePlaces(apiKey);
      break;
    case 'describe':
      await generateDescriptions();
      break;
    case 'taiwan-tourism':
      await fetchTaiwanTourism();
      break;
    default:
      console.log(`
嘉義探索 App - OSM 地點自動抓取工具
══════════════════════════════════════

  node chiayi_osm_seeder.js fetch
    → 從 OpenStreetMap 抓取嘉義所有地點，儲存到 data/osm_data.json

  node chiayi_osm_seeder.js upload
    → 把 data/osm_data.json 上傳到 Firebase

  node chiayi_osm_seeder.js all
    → fetch + upload 一次完成 ⭐ 推薦

  node chiayi_osm_seeder.js enrich YOUR_GOOGLE_API_KEY
    → 用 Google Places API 補齊 places_test 和 restaurants_test 的評分

  node chiayi_osm_seeder.js taiwan-tourism
    → 從交通部觀光署補齊嘉義景點的中文簡介與官方照片 ⭐ 免費！

  node chiayi_osm_seeder.js describe
    → 用 Claude AI 生成中文簡介（需設定 ANTHROPIC_API_KEY）

使用前請先：
  npm install firebase-admin node-fetch
  把 serviceAccountKey.json 放在此目錄
`);
  }

  process.exit(0);
}

main().catch(err => {
  console.error('\n❌ 執行錯誤：', err.message);
  console.error(err.stack);
  process.exit(1);
});