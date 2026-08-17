# Shadow Blade ⚔️

A highly optimized local multiplayer 2D fighting game designed specifically for Android TVs (and mobile devices). Built using **Flutter** and the **Flame Engine**. 

Instead of traditional remotes, this game turns players' smartphones into virtual console controllers using WebSockets, offering a seamless and lag-free combat experience!

### ✨ Key Features
* 📺 **TV Optimized:** Runs smoothly even on 1GB RAM Android TVs.
* 📱 **Smart Mobile Controllers:** Scan the IP on your TV and use your phone browser as a glassmorphism virtual joystick/gamepad.
* 🥷 **Action-Packed Combat:** Sword attacks, custom shuriken throws, dynamic blocking, and dash moves.
* 🎨 **Dynamic UI:** Responsive custom health bars with dynamic coloring and player names.
* 🎵 **Immersive Audio:** Complete background music and combat sound effects (flame_audio).

### 🛠️ Tech Stack
* **Game Engine:** Flutter & Flame
* **Network/Controllers:** WebSockets (Dart `dart:io`) & HTML/CSS/JS (Virtual Joystick) 

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
