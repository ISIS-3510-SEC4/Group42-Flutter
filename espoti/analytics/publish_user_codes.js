// Publica en user_codes/{CODIGO} el código de amigo de TODOS los usuarios que
// ya existen en users/{uid}, para que se puedan buscar por código aunque
// todavía no hayan abierto la versión nueva de la app.
// Solo copia datos públicos: uid, código, nombre y foto (nunca correo ni
// teléfono). Si dos usuarios tienen el mismo código, se publica el primero y
// se informa el conflicto: el otro recibirá un código nuevo al abrir la app.
// Uso (mismas credenciales que los otros scripts):
//   node analytics/publish_user_codes.js
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "moviles-9132d"
});

function normalize(code) {
  return String(code || "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

async function main() {
  const db = getFirestore();
  const users = await db.collection("users").get();
  let published = 0;
  let skipped = 0;
  const conflicts = [];

  for (const doc of users.docs) {
    const data = doc.data();
    const uid = data.firebaseUid || doc.id;
    const code = normalize(data.code);
    if (!code) {
      skipped++;
      continue;
    }
    const ref = db.collection("user_codes").doc(code);
    const existing = await ref.get();
    if (existing.exists && existing.data().uid !== uid) {
      conflicts.push(`${code}: ${existing.data().uid} / ${uid}`);
      continue;
    }
    await ref.set({
      uid,
      code,
      name: data.name || "",
      avatarUrl: data.avatarUrl || "",
      updatedAt: FieldValue.serverTimestamp()
    });
    published++;
  }

  console.log(`Códigos publicados: ${published}`);
  console.log(`Usuarios sin código: ${skipped}`);
  if (conflicts.length) {
    console.log("Códigos repetidos (el segundo usuario recibirá uno nuevo al abrir la app):");
    conflicts.forEach(c => console.log("  " + c));
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
