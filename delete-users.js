import fs from "fs";
import admin from "firebase-admin";

admin.initializeApp();

const data = JSON.parse(fs.readFileSync("users.json", "utf8"));
const users = data.users || [];

async function run() {
  for (const user of users) {
    await admin.auth().deleteUser(user.localId);
    console.log("Deleted:", user.localId);
  }
  console.log("✅ All users deleted");
}

run().catch(console.error);
