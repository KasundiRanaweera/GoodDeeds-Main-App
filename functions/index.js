/**
 * Firebase Functions entrypoint (JavaScript).
 */

const admin = require("firebase-admin");
const {setGlobalOptions} = require("firebase-functions");

setGlobalOptions({maxInstances: 10});
admin.initializeApp();
