# My Journey 🌍

> *Recording the beauty of life — a personal memoir of your journey*

My Journey is a Flutter-based mobile application built for the CASA0015 Mobile Systems & Interactions module at UCL. It sits at the intersection of a personal diary and a community discovery platform. My Journey is a connected environment tool that transforms real-world movement and exploration into a living, evolving memoir.

Using GPS and the device accelerometer, the app continuously tracks where users have been, revealing explored areas through a fog-of-war overlay that makes every journey feel like an unfolding story. Users can check in at meaningful places such as restaurants, landmarks, hidden gems, attach labels, photos, notes, and real-time weather data captured at the moment of arrival, building a rich, contextual record of their lives.

Beyond personal memory, My Journey connects people. Locations can be shared to social media as branded cards or posted to a public community noticeboard, where others can discover and import them — turning private memories into shared recommendations. A friends leaderboard adds a playful layer of competition, encouraging users to keep exploring.

<div align="center">
  <img src="https://github.com/Annie-Zhu1210/CASA0015_MyJourneyApp/raw/main/Media/Splash%20Screen.gif" width="150">
</div>

---

## Demo

The three Demo videos show the **long-press to check in, check-in location organisation, and share features**, respectively.
<div align="center">
  <img src="https://github.com/Annie-Zhu1210/CASA0015_MyJourneyApp/blob/main/Media/Demo1.gif" width="250">
  &nbsp;&nbsp;&nbsp;
  <img src="https://github.com/Annie-Zhu1210/CASA0015_MyJourneyApp/blob/main/Media/Demo2.gif" width="250">
  &nbsp;&nbsp;&nbsp;
  <img src="https://github.com/Annie-Zhu1210/CASA0015_MyJourneyApp/blob/main/Media/Demo3.gif" width="250">
</div>

---

## Motivation

We visit meaningful places every day — a favourite café, a hidden park, a restaurant we want to remember — but most of those moments fade. Existing tools either feel too public (social media) or too plain (notes apps). There is no dedicated space that is both a personal record of your physical journey *and* a way to share those discoveries with people you trust.

My Journey solves this by giving users a map-centred, sensor-aware tool to capture places in the moment, build a meaningful archive over time, and share selectively — with close friends or the wider community.

---

## Features

### Map & Exploration
- Real-time GPS tracking with a live custom avatar marker
- **Exploration Path** (fog-of-war overlay) — the map dims everywhere you have not been, and reveals areas as you physically visit them, creating a visual record of your world
- Three map styles: Standard, Satellite, and Dark
- Tap the location FAB to re-centre the map on your position
- **Floating weather widget** showing live temperature and conditions at your current location

### Check-In System
- Long-press anywhere on the map to save a check-in at that location
- Choose from 12 preset emoji labels (Favourite, Food, Café, Bar, Attraction, Shopping, Nature, Music, Art, Hotel, Study, Gym) or use any custom emoji
- Add a place name, personal notes, and photos from your gallery or camera
- Option to attach the **real-time weather** at the moment of check-in — so "it was sunny in Paris" is captured forever
- Edit or delete any check-in at any time

### Shake to Check-In
- Shake your phone to instantly save a check-in at your current GPS location
- Auto-named ("Untitled 1", "Untitled 2", …) with weather captured automatically — designed for spontaneous moments when you don't want to stop and type
- Uses the device **accelerometer sensor** with a configurable threshold and cooldown to prevent accidental triggers
- A brief toast notification confirms the save

### Locations Screen
- Full list of all your saved check-ins with reverse geocoding (city and country displayed on each card)
- Four grouping tabs:
  - **City** — automatically groups check-ins by the city they were saved in
  - **Label** — groups by emoji label type
  - **My Collections** — user-created custom collections with drag-and-drop ordering; locations can be dragged directly onto a collection card to add them
  - **From Friends** — locations imported from the community noticeboard
- Tap any check-in to open a full detail view showing weather, notes, photos, coordinates, and date saved
- Edit, delete, and share from the detail view

### World Screen
- **Cities Visited** — count of unique cities explored, tap to see the full list
- **Countries Visited** — count with flag emojis, tap to see the full list
- **Friends** — friend count, tap to manage your friends list
- **My Race** — leaderboard comparing your cities and countries count against friends, with a pyramid podium for the top three
- **Community Noticeboard** — a real-time public feed of locations shared by all users; tap a card to read full details and import it to your From Friends list; long-press your own posts to delete them

### Friends & Social
- Add friends by username (`@handle`) or unique friend code (`JOURNEY-XXXX`)
- Mutual friendship — adding someone adds you to their list too
- Toggle location privacy per friend (groundwork for future live location sharing)
- My Race leaderboard with Cities and Countries tabs, gold / silver / bronze podium styling

### Share
- Share any location two ways from the detail screen or map info panel:
  - **Share to Social Media** — generates a branded card image and opens the iOS native share sheet for WhatsApp, Instagram, Messages, etc.
  - **Post to Noticeboard** — publishes the location to the in-app community feed for others to discover and import

### Account & Settings
- Google Sign-In via Firebase Authentication — mandatory on first launch, remembered on return
- Animated splash screen on first load
- Set a unique `@username` (prompted on first login, editable in Settings)
- Shareable friend code displayed in Settings
- Upload a custom avatar (stored as Base64 in Firestore)
- Map style preference (Standard / Satellite / Dark), persisted across sessions
- Log out or permanently delete account with full data cleanup

---

## Technical Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Maps | Google Maps Flutter SDK |
| Location | geolocator |
| Reverse Geocoding | Google Maps Geocoding API + geocoding package |
| Weather | OpenWeatherMap API (Current Weather) |
| Sensors | sensors_plus (accelerometer — shake detection) |
| Auth | Firebase Authentication (Google Sign-In) |
| Cloud Database | Cloud Firestore |
| Local Database | SQLite via sqflite |
| Local Storage | shared_preferences |
| Photo Handling | image_picker, path_provider, path |
| Sharing | share_plus |
| UI Font | Google Fonts (Comfortaa) |

---

## Project Structure

```
lib/
├── constants/          # Label presets, secrets (gitignored)
├── models/             # CheckInLocation, CustomCollection, Friend
├── screens/            # All full-screen views
│   ├── map_screen.dart
│   ├── locations_screen.dart
│   ├── world_screen.dart
│   ├── settings_screen.dart
│   ├── login_screen.dart
│   ├── friends_screen.dart
│   ├── my_race_screen.dart
│   ├── location_detail_screen.dart
│   ├── collection_detail_screen.dart
│   ├── custom_collection_detail_screen.dart
│   ├── cities_visited_screen.dart
│   └── countries_visited_screen.dart
├── services/           # Business logic and data access
│   ├── auth_service.dart
│   ├── checkin_database.dart
│   ├── collections_database.dart
│   ├── exploration_service.dart
│   ├── geocoding_service.dart
│   ├── friends_service.dart
│   ├── noticeboard_service.dart
│   ├── share_service.dart
│   ├── shake_checkin_service.dart
│   ├── user_profile_service.dart
│   └── weather_service.dart
└── widgets/            # Reusable UI components
    ├── animated_bottom_nav_bar.dart
    ├── splash_overlay.dart
    └── checkin/
        ├── checkin_level1_dialog.dart
        ├── checkin_editor.dart
        ├── checkin_info_panel.dart
        └── label_picker.dart
```

---

## Installation

### Android — Direct APK Install

An Android release APK is available for direct installation without needing Flutter or Xcode.

1. Download `app-release.apk` from the [latest release](https://github.com/Annie-Zhu1210/CASA0015_MyJourneyApp/releases/tag/v1.0.0)
2. Transfer it to your Android device
3. Enable **Install from Unknown Sources** in your device settings if prompted
4. Open the APK file to install

### iOS — Build from Source

iOS does not permit sideloading APK files. To run the app on iOS you need to build it locally using Flutter and Xcode.

**Prerequisites**
- Flutter SDK 3.x or above — [install guide](https://docs.flutter.dev/get-started/install)
- Xcode 15 or above (Mac only)
- A physical iPhone or the iOS Simulator
- A Firebase project with Authentication and Firestore enabled
- A Google Maps API key (Maps SDK for iOS + Geocoding API enabled)
- An OpenWeatherMap API key (free tier)

**Steps**

1. Clone the repository
   ```bash
   git clone https://github.com/Annie-Zhu1210/CASA0015_MyJourneyApp.git
   cd CASA0015_MyJourneyApp
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Create `lib/constants/secrets.dart` (gitignored — you must create this file yourself):
   ```dart
   class Secrets {
     static const String geocodingApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
     static const String openWeatherApiKey = 'YOUR_OPENWEATHER_API_KEY';
   }
   ```

4. Add your Google Maps API key to `ios/Runner/Secrets.swift` (also gitignored):
   ```swift
   let googleMapsApiKey = "YOUR_GOOGLE_MAPS_API_KEY"
   ```

5. Place your `GoogleService-Info.plist` inside `ios/Runner/` (gitignored — obtain from your Firebase Console)

6. Open the iOS project in Xcode to set your development team, then run:
   ```bash
   flutter run
   ```

> **Note:** Location services, the accelerometer, and the camera require a physical device. The iOS Simulator will not produce real GPS positions or respond to shake gestures.

---

## Future Improvements

- **Real-time friend location sharing** — the privacy toggle and Firestore data model are in place; the map rendering layer for friends' live positions is the remaining piece
- **Journey timeline** — a chronological activity feed showing check-ins and exploration milestones over time
- **Community noticeboard photos** — currently text-only to avoid Firebase Storage billing; photo support is a natural next step
- **Noticeboard privacy** — currently public to all users; a friends-only mode would improve trust for personal recommendations
- **Android refinement** — the app targets iOS primarily; the Android APK builds and runs but has not been fully tested on physical Android hardware
- **Cloud sync for exploration path** — the fog-of-war path is currently stored on-device only; syncing it to Firestore would allow multi-device continuity

---

## Bibliography

1. Baseflow (2023) *geocoding* (Version 2.1.0) [Software]. pub.dev. Available at: https://pub.dev/packages/geocoding (Accessed: 29 April 2026)
2. Baseflow (2023) *geolocator* (Version 10.1.0) [Software]. pub.dev. Available at: https://pub.dev/packages/geolocator (Accessed: 29 April 2026)
3. Flutter Community (2023) *sensors_plus* (Version 4.0.2) [Software]. pub.dev. Available at: https://pub.dev/packages/sensors_plus (Accessed: 29 April 2026)
4. Flutter Community (2025) *share_plus* (Version 10.1.4) [Software]. pub.dev. Available at: https://pub.dev/packages/share_plus (Accessed: 29 April 2026)
5. Flutter.dev (2024) *google_fonts* (Version 6.2.1) [Software]. pub.dev. Available at: https://pub.dev/packages/google_fonts (Accessed: 29 April 2026)
6. Flutter.dev (2023) *google_maps_flutter* (Version 2.5.0) [Software]. pub.dev. Available at: https://pub.dev/packages/google_maps_flutter (Accessed: 29 April 2026)
7. Flutter.dev (2023) *google_sign_in* (Version 6.2.1) [Software]. pub.dev. Available at: https://pub.dev/packages/google_sign_in (Accessed: 29 April 2026)
8. Flutter.dev (2024) *image_picker* (Version 1.1.2) [Software]. pub.dev. Available at: https://pub.dev/packages/image_picker (Accessed: 29 April 2026)
9. Flutter.dev (2023) *shared_preferences* (Version 2.2.2) [Software]. pub.dev. Available at: https://pub.dev/packages/shared_preferences (Accessed: 29 April 2026)
10. Google LLC (2024) *Cloud Firestore* [Online]. Firebase. Available at: https://firebase.google.com/docs/firestore (Accessed: 29 April 2026)
11. Google LLC (2024) *Firebase Authentication* [Online]. Firebase. Available at: https://firebase.google.com/docs/auth (Accessed: 29 April 2026)
12. Google LLC (2024) *Geocoding API* [Online]. Google for Developers. Available at: https://developers.google.com/maps/documentation/geocoding (Accessed: 29 April 2026)
13. Google LLC (2024) *Maps SDK for Android* [Online]. Google for Developers. Available at: https://developers.google.com/maps/documentation/android-sdk (Accessed: 29 April 2026)
14. Google LLC (2024) *Maps SDK for iOS* [Online]. Google for Developers. Available at: https://developers.google.com/maps/documentation/ios-sdk (Accessed: 29 April 2026)
15. Tekartik (2024) *sqflite* (Version 2.3.2) [Software]. pub.dev. Available at: https://pub.dev/packages/sqflite (Accessed: 29 April 2026)

---

## Contact

**Annie Zhu**
MSc Connected Environments, University College London

GitHub: [@Annie-Zhu1210](https://github.com/Annie-Zhu1210)

---
## Use of Generative AI

This project was developed under **UCL Category 2** AI use guidelines, where Generative AI tools are permitted in an assistive role.

[Claude](https://claude.ai) (Anthropic) was used throughout development as a coding assistant to help implement, debug, and refine Flutter/Dart code. All code was reviewed, tested, and integrated by the author on a physical device. The overall app architecture, design decisions, and feature direction were determined by the author.

Specific areas where AI assistance was used include:
- Implementing complex UI widgets and custom painters (exploration path overlay, animated bottom navigation bar, avatar marker builder)
- Debugging platform-specific iOS issues (photo persistence, Firebase Auth race conditions, geocoding API integration)
- Structuring Firestore data models for friends, noticeboard, and imported locations
- Writing service classes for shake detection, weather fetching, and share card rendering

---
## 📄 Licence

This project was developed as individual coursework for CASA0015: Mobile Systems & Interactions at University College London (UCL). All rights reserved.
