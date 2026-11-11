// Run only from a trusted workstation with application default credentials.
import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
const uid=process.argv[2];
if(!uid) throw new Error('Usage: node tools/set-admin.mjs USER_UID');
initializeApp({credential:applicationDefault()});
const auth=getAuth();
const user=await auth.getUser(uid);
await auth.setCustomUserClaims(uid,{...user.customClaims,admin:true});
console.log('Admin role assigned. Sign out and sign in again.');
