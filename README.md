# DesertEye

A Flutter-based offline map and mesh communication app designed for outdoor adventures and emergency situations. DesertEye integrates with Meshtastic devices to enable off-grid communication and mutual tracking between group members.

## Features

### Map & Navigation
- **OpenStreetMap tiles** with offline caching support
- **GPX track loading** - Import and display hiking/biking routes
- **Location tracking** with multiple modes:
  - North-up orientation
  - Heading-up (map rotates with movement direction)
- **Offline map download** - Cache map regions for areas without connectivity

### Meshtastic Integration
- **Bluetooth Low Energy (BLE)** connection to Meshtastic devices
- **Node tracking** - See other mesh network members on the map with real-time position updates
- **Mesh chat** - Send and receive text messages through the mesh network
- **Auto-reconnect** - Automatically connects to last used device on startup

### Emergency Features
- **SOS button** - Send emergency alerts with your GPS position to all mesh network members
- **Emergency notifications** - Receive and display incoming SOS alerts from other users
- **Navigate to emergency** - Quick navigation to a distressed user's location

### UI/UX
- **Auto-hiding controls** - Clean map view with controls that appear on interaction
- **Portrait/Landscape modes** - Optimized layouts for both orientations
- **Screen brightness control** - Quick access brightness slider
- **Always-on display** - Screen stays active during navigation
- **Background service** - Maintains Bluetooth connection when app is backgrounded

## Screenshots

The app displays an interactive map with your position, other Meshtastic nodes, and control buttons for navigation, communication, and emergency features.

## How to Use

### First Launch
1. Grant location and Bluetooth permissions when prompted
2. The app will show your current position on the map

### Connecting to Meshtastic
1. Tap the **Bluetooth button** (right side) to scan for devices
2. Select your Meshtastic device from the list
3. Once connected, the button turns green and shows a badge with the number of nodes in range
4. The app remembers your device and auto-connects on next launch

### Map Controls (Right Side)
- **Portrait/Landscape** - Toggle screen orientation
- **Bluetooth** - Connect/disconnect Meshtastic device
- **Download** - Cache visible map area for offline use (only when online)
- **Location** - Toggle tracking modes (tap cycles through: off > north-up > heading-up)
- **File** - Load a GPX track file
- **Clear** - Remove loaded GPX tracks (appears when tracks are loaded)

### Chat (Bottom Left)
1. Tap the **chat bubble** to open the messaging panel
2. Select a channel or direct message recipient
3. Type your message and send
4. Unread messages show a notification badge

### SOS Emergency
1. Tap the **SOS button** (red, left side)
2. A confirmation dialog appears with a countdown timer
3. Slide to cancel, or wait for automatic send
4. Your position and emergency message are broadcast to all mesh nodes
5. When receiving an SOS, tap "Navigate" to center map on the sender's position

### Brightness Control
- Tap the **sun icon** (right edge) to expand brightness slider
- Drag to adjust screen brightness
- Tap "Auto" to return to automatic brightness

### Offline Use
1. While online, navigate to your area of interest
2. Tap the **download button** to cache map tiles
3. The app works fully offline once tiles are cached and Meshtastic is connected

## Requirements

- Android 8.0+ (API 26+)
- Bluetooth Low Energy support
- Location permissions
- A Meshtastic-compatible device for mesh features

## Building

```bash
flutter pub get
flutter run
```

## Dependencies

Key packages used:
- `flutter_map` - Map rendering
- `flutter_blue_plus` - Bluetooth connectivity
- `latlong2` - Geographic calculations
- `gpx` - GPX file parsing
- `flutter_local_notifications` - System notifications
- `flutter_background_service` - Background execution
- `screen_brightness` - Display brightness control

## License

This project is provided as-is for personal and educational use.
