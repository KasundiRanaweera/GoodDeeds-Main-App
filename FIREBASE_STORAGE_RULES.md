
# Firebase Security Rules (Storage + Firestore)

Both Storage and Firestore rules are required for secure role-based access in GoodDeeds App.

## Quick Permissions Reference

| Collection/Path          | Read         | Create         | Update                                                                 | Delete                                     |
|-------------------------|--------------|----------------|------------------------------------------------------------------------|--------------------------------------------|
| `/users/{userId}`       | Public       | Owner only     | Owner only, or organizer attendance/reward update only                 | No                                         |
| `/user_profiles/{uid}`  | Public       | Owner only     | Owner only                                                             | No                                         |
| `/events/{eventId}`     | Public       | Organizer only | Signed-in join/leave fields, organizer attendance fields, or event owner full update | Organizer or event owner                    |
| `/storage/events/{uid}` | Public       | Owner only     | Owner only                                                             | Owner only                                 |

## 1) Firebase Storage Rules

Go to Firebase Console -> Storage -> Rules, then use:

```rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /events/{userId}/{allPaths=**} {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if true;
    }
  }
}
```

## 2) Firestore Rules

Source of truth is `firestore.rules` in this repo. Deploy it with:

```bash
firebase deploy --only firestore:rules
```

Current Firestore rules:

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    function currentUserPath() {
      return /databases/$(database)/documents/users/$(request.auth.uid);
    }

    function isOrganizer() {
      return isSignedIn() &&
        exists(currentUserPath()) &&
        (
          get(currentUserPath()).data.role == 'Organizer' ||
          get(currentUserPath()).data.role == 'organizer' ||
          get(currentUserPath()).data.isOrganizer == true ||
          (
            get(currentUserPath()).data.roles is list &&
            get(currentUserPath()).data.roles.hasAny([
              'Organizer',
              'organizer',
            ])
          )
        );
    }

    function eventAttendanceOpen(eventData) {
      return (
        eventData.eventDate is timestamp &&
        request.time >= eventData.eventDate &&
        request.time <= eventData.eventDate + duration.value(2, 'd')
      ) || (
        eventData.date is timestamp &&
        request.time >= eventData.date &&
        request.time <= eventData.date + duration.value(2, 'd')
      ) || (
        eventData.startDate is timestamp &&
        request.time >= eventData.startDate &&
        request.time <= eventData.startDate + duration.value(2, 'd')
      );
    }

    function pointsFieldChanged() {
      return request.resource.data.impactPoints != resource.data.impactPoints ||
        request.resource.data.totalPoints != resource.data.totalPoints ||
        request.resource.data.rewardPoints != resource.data.rewardPoints ||
        request.resource.data.points != resource.data.points;
    }

    function oldPoints() {
      return (resource.data.impactPoints is int)
        ? resource.data.impactPoints
        : ((resource.data.totalPoints is int)
          ? resource.data.totalPoints
          : ((resource.data.rewardPoints is int)
            ? resource.data.rewardPoints
            : ((resource.data.points is int)
              ? resource.data.points
              : 0)));
    }

    function newPoints() {
      return (request.resource.data.impactPoints is int)
        ? request.resource.data.impactPoints
        : ((request.resource.data.totalPoints is int)
          ? request.resource.data.totalPoints
          : ((request.resource.data.rewardPoints is int)
            ? request.resource.data.rewardPoints
            : ((request.resource.data.points is int)
              ? request.resource.data.points
              : 0)));
    }

    function arePointFieldsAligned() {
      return request.resource.data.impactPoints == request.resource.data.totalPoints &&
        request.resource.data.totalPoints == request.resource.data.rewardPoints &&
        request.resource.data.rewardPoints == request.resource.data.points;
    }

    function pointDeltaWithinEventRange() {
      return (newPoints() - oldPoints()) <= 200 &&
        (newPoints() - oldPoints()) >= -200 &&
        newPoints() >= 0;
    }

    function isOrganizerAttendanceRewardUpdate() {
      return isOrganizer() &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly([
          'impactPoints',
          'totalPoints',
          'rewardPoints',
          'points',
          'participationStatusByEvent',
          'attendanceVerifiedAtByEvent',
          'updatedAt'
        ]) &&
        (
          !pointsFieldChanged() ||
          (arePointFieldsAligned() && pointDeltaWithinEventRange())
        );
    }

    match /users/{userId} {
      allow read: if true;
      allow create: if isOwner(userId);
      allow update: if isOwner(userId) || isOrganizerAttendanceRewardUpdate();
      allow delete: if false;
    }

    match /user_profiles/{userId} {
      allow read: if true;
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
      allow delete: if false;
    }

    match /events/{eventId} {
      allow read: if true;
      allow create: if isOrganizer();

      allow update: if isSignedIn() &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['participantIds', 'participantsCount', 'updatedAt']);

      allow update: if isOrganizer() &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['checkedInIds', 'awardedParticipantIds', 'updatedAt']) &&
        eventAttendanceOpen(resource.data);

      allow update: if isSignedIn() && resource.data.createdByUid == request.auth.uid;
      allow delete: if isSignedIn() && (resource.data.createdByUid == request.auth.uid || isOrganizer());
    }
  }
}
```

## 3) After Publishing Rules

1. Publish Storage rules.
2. Deploy Firestore rules from this repo.
3. Wait 1-2 minutes.
4. Sign out and sign in again.
5. Test organizer attendance marking on mobile.

## Quick Troubleshooting

- `cloud_firestore/permission-denied` while marking attendance:
  Organizer role fields in `users/{uid}` do not match rule expectations, or event date is outside the allowed 2-day attendance window.
- Upload spinner never ends:
  Storage write permissions or network issue.
- User not authenticated:
  Session expired, sign in again.
