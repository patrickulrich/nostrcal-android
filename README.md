# NostrCal

![purplestack](assets/images/purplestack.png)

A decentralized calendar application built on the Nostr protocol. NostrCal enables users to create, discover, and manage calendar events in a censorship-resistant, peer-to-peer environment using NIP-52 calendar events.

## Features

- **📅 Calendar Events**: Create and manage date-based (NIP-52 kind 31922) and time-based (NIP-52 kind 31923) calendar events
- **🔍 Event Discovery**: Browse and search public calendar events with advanced filtering (by time, location, tags)
- **📱 RSVP Support**: Respond to calendar events with NIP-52 kind 31925 RSVPs
- **🔐 Nostr Authentication**: Secure login using Amber signer (NIP-55) for Android
- **⚡ Real-time Updates**: Live event streaming from Nostr relays with local-first architecture
- **🎨 Material 3 Design**: Modern, accessible interface with light/dark theme support
- **📄 Pagination**: Efficient event loading with exponential pagination (100→200→400→800→1600)
- **🏷️ Rich Event Details**: Support for titles, descriptions, locations, images, participants, hashtags, and references
- **📊 Custom Availability**: Extended NIP-52 implementation with calendar availability templates and privacy-preserving busy blocks

## NIP Compliance

NostrCal implements and extends the NIP-52 specification:

- **NIP-52 Core**: Date-based events (31922), time-based events (31923), calendars (31924), RSVPs (31925)
- **NIP-52 Extensions**: Calendar availability (31926) and availability blocks (31927) for booking systems
- **NIP-55**: Android signer integration with Amber
- **NIP-44**: Encryption support for private events

## Technology Stack

Built with the Purplestack development framework, featuring:

- **Flutter**: Cross-platform mobile development
- **Riverpod**: Reactive state management
- **Purplebase**: Local-first Nostr SDK with SQLite storage
- **Material 3**: Modern design system
- **Table Calendar**: Interactive calendar widget

## Installation

### Prerequisites

- Android device (arm64-v8a architecture)
- [Amber Signer](https://github.com/greenart7c3/Amber) installed for Nostr authentication

### Download

Download the latest APK from the releases or build from source.

### Building from Source

```bash
# Clone the repository
git clone <repository-url>
cd purplestack

# Install dependencies
fvm flutter pub get

# Build APK
fvm flutter build apk --target-platform android-arm64 --split-per-abi
```

## Development

This project uses the Purplestack development stack designed for AI agents to build Nostr-enabled Flutter applications.

## Sample environment setup

For MacOS (may work with Homebrew on Linux) and just for guidance. View the respective projects' documentation for more.

```bash
# Install Android
brew install android-commandlinetools
# add to shell's rc file ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools

# Install Java
brew install openjdk@17

# Install Dart
brew tap dart-lang/dart
brew install dart
dart --disable-analytics
dart pub global activate fvm

# Install Flutter
fvm releases
fvm install <version>

sdkmanager --install "platforms;android-35"
sdkmanager --install "build-tools;35.0.0"
sdkmanager --install emulator platform-tools tools
sdkmanager --licenses

sdkmanager --install "system-images;android-30;google_apis;arm64-v8a"
avdmanager create avd --name "pixel_8" --package "system-images;android-35;google_apis;arm64-v8a" --abi "arm64-v8a" --device "pixel_8"
```

## License

MIT