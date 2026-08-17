# Shadow Blade ⚔️

A local multiplayer Android TV fighting game built with Flutter and Flame.

Players connect their mobile devices to the TV over the local WiFi network using a Web-based Virtual Gamepad (HTML/JS/CSS served directly from the Dart server). 

## Features
- **Android TV Support**: Native Leanback launcher support and adaptive icons.
- **Web Gamepad Controller**: No app installation needed for players! Just scan/type the IP displayed on the TV to connect.
- **Zero Latency**: Direct WebSocket communication over LAN.
- **Virtual Joystick**: Modern glassmorphism analog stick for fluid mobile control.

## Getting Started

1. Ensure your Android TV and Mobile device are on the same WiFi network.
2. Build and install the APK on your TV:
   ```bash
   flutter build apk --release --split-per-abi
   ```
3. Open the game on the TV. It will display a local IP address (e.g., `http://192.168.1.5:8080`).
4. Type that address into your mobile browser to join the lobby!

## License

This project is Free and Open Source Software (FOSS) licensed under the **MIT License**.

MIT License

Copyright (c) 2026 Rasindu Perera

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
