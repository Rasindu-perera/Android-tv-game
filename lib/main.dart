import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flame/game.dart';
import 'game.dart';

// --------------------------------------------------------
// HTML/JS/CSS Payload for the phone client
// --------------------------------------------------------
const String clientHtml = '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <title>TV Game Controller</title>
    <style>
        * { box-sizing: border-box; touch-action: manipulation; }
        html, body {
            margin: 0; 
            padding: 0; 
            overflow: hidden; 
            height: 100%;
            width: 100%;
        }
        body {
            background: radial-gradient(circle at center, #222 0%, #000 100%);
            color: #ffffff;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            user-select: none;
            -webkit-user-select: none;
        }
        
        /* Lobby Styles */
        #lobbyContainer {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            width: 100%;
        }
        h1 { margin-top: 10px; font-size: 28px; margin-bottom: 5px; text-shadow: 0 0 10px rgba(255,255,255,0.3); }
        .skills-container {
            display: flex;
            gap: 20px;
            margin-top: 20px;
        }
        .skill-btn {
            background-color: rgba(255, 255, 255, 0.05);
            color: white;
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 12px;
            padding: 15px 30px;
            font-size: 20px;
            cursor: pointer;
            transition: all 0.2s;
            text-transform: uppercase;
            font-weight: bold;
        }
        .skill-btn.selected {
            background-color: rgba(0, 230, 118, 0.2);
            color: #00e676;
            border-color: #00e676;
            transform: scale(1.05);
            box-shadow: 0 0 15px rgba(0, 230, 118, 0.5);
        }
        .ready-btn {
            margin-top: 30px;
            background-color: rgba(255, 61, 0, 0.8);
            color: white;
            border: 1px solid #ff3d00;
            border-radius: 8px;
            padding: 15px 50px;
            font-size: 22px;
            font-weight: bold;
            visibility: hidden;
            box-shadow: 0 0 15px rgba(255, 61, 0, 0.5);
            transition: all 0.2s;
        }
        .ready-btn.visible { visibility: visible; }
        .ready-btn:active { transform: scale(0.95); }
        #status { margin-top: 5px; color: #aaa; font-size: 16px; }

        /* Game Over Styles */
        #gameOverContainer {
            display: none;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            width: 100%;
        }

        /* Controller Styles */
        #controllerContainer {
            display: none; /* Flex when active */
            position: relative;
            width: 100%;
            height: 100vh;
            height: 100dvh;
            box-sizing: border-box;
            padding: 10px 30px;
            padding-bottom: env(safe-area-inset-bottom, 10px);
            padding-left: env(safe-area-inset-left, 30px);
            padding-right: env(safe-area-inset-right, 30px);
            justify-content: space-between;
            align-items: center;
        }

        .quit-btn {
            position: absolute;
            top: 15px;
            right: 15px;
            background-color: transparent;
            color: rgba(255, 255, 255, 0.5);
            border: 1px solid rgba(255, 255, 255, 0.3);
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 12px;
            cursor: pointer;
            transition: all 0.2s;
        }
        .quit-btn:active { background-color: rgba(255, 255, 255, 0.1); }

        /* Joystick (Left Side) */
        #joystick-zone {
            width: 150px;
            height: 150px;
            background-color: rgba(255, 255, 255, 0.05);
            border: 2px solid rgba(255, 255, 255, 0.15);
            border-radius: 50%;
            position: relative;
            display: flex;
            justify-content: center;
            align-items: center;
            box-shadow: 0 0 20px rgba(0, 255, 255, 0.05);
            touch-action: none;
            margin-left: 10px;
            transform: scale(0.9);
            transform-origin: center left;
        }
        
        #joystick-knob {
            width: 60px;
            height: 60px;
            background-color: rgba(255, 255, 255, 0.8);
            border-radius: 50%;
            position: absolute;
            box-shadow: 0 0 15px rgba(0, 255, 255, 0.5);
            pointer-events: none;
        }
        #joystick-knob.snapping {
            transition: transform 0.2s ease-out;
        }
        
        .ctrl-btn { 
            border-radius: 50%; 
            background-color: rgba(255, 255, 255, 0.08);
            color: rgba(255, 255, 255, 0.8);
            border: 1px solid rgba(255, 255, 255, 0.15);
            font-size: 12px;
            font-weight: bold;
            display: flex;
            justify-content: center;
            align-items: center;
            transition: transform 0.1s, box-shadow 0.1s, background-color 0.1s;
            box-shadow: 0 0 10px rgba(0, 255, 255, 0.1);
            user-select: none;
            -webkit-tap-highlight-color: transparent;
        }
        


        /* Action Buttons (Right Side) */
        .action-pad {
            position: relative;
            width: 280px;
            height: 280px;
            transform: scale(0.9);
            transform-origin: center right;
        }
        
        .action-btn {
            position: absolute;
            box-shadow: 0 0 15px rgba(255, 255, 255, 0.1);
        }
        
        /* Diamond Layout */
        .btn-punch {
            top: 20px;
            left: 90px;
            width: 100px;
            height: 100px;
            font-size: 18px;
            border-color: rgba(255, 61, 0, 0.5);
            box-shadow: 0 0 20px rgba(255, 61, 0, 0.3);
        }
        
        .btn-kick {
            top: 110px;
            left: 0px;
            width: 80px;
            height: 80px;
            border-color: rgba(255, 152, 0, 0.5);
            box-shadow: 0 0 15px rgba(255, 152, 0, 0.3);
        }
        
        .btn-block {
            top: 110px;
            left: 180px;
            width: 80px;
            height: 80px;
            border-color: rgba(0, 229, 255, 0.5);
            box-shadow: 0 0 15px rgba(0, 229, 255, 0.3);
        }

        .skill-action-btn {
            position: absolute;
            width: 70px;
            height: 70px;
            border-radius: 50%;
            border-color: rgba(41, 182, 246, 0.5);
            box-shadow: 0 0 15px rgba(41, 182, 246, 0.3);
        }
        #skillBtn1 { top: 200px; left: 50px; }
        #skillBtn2 { top: 200px; left: 130px; }
        
        /* Active State */
        .active { 
            transform: scale(0.9);
            background-color: rgba(255, 255, 255, 0.2);
        }
        .btn-punch.active { box-shadow: 0 0 30px rgba(255, 61, 0, 0.8); border-color: #ff3d00; background-color: rgba(255, 61, 0, 0.3); }
        .btn-kick.active { box-shadow: 0 0 25px rgba(255, 152, 0, 0.8); border-color: #ff9800; background-color: rgba(255, 152, 0, 0.3); }
        .btn-block.active { box-shadow: 0 0 25px rgba(0, 229, 255, 0.8); border-color: #00e5ff; background-color: rgba(0, 229, 255, 0.3); }
        .ctrl-btn.active { box-shadow: 0 0 20px rgba(0, 255, 255, 0.5); border-color: #00ffff; }
        .skill-cooldown { opacity: 0.3; }
    </style>
</head>
<body>
    
    <!-- JOIN UI -->
    <div id="joinContainer" style="display:flex; flex-direction: column; align-items: center; justify-content: center; height: 100%; width: 100%;">
        <h1 id="joinTitle">Shadow Blade</h1>
        <div id="joinStatus">Connecting to TV...</div>
        <input type="text" id="playerNameInput" placeholder="Enter Player Name" style="display:none; padding: 10px; font-size: 18px; border-radius: 8px; border: 1px solid #555; background: rgba(0,0,0,0.5); color: white; margin-bottom: 20px; text-align: center;">
        <button class="ready-btn" id="joinBtn" onclick="sendJoin()" style="display:none;">JOIN GAME</button>
    </div>

    <!-- LOBBY UI -->
    <div id="lobbyContainer" style="display:none;">
        <h1 id="title">Connecting...</h1>
        <div id="status">Connecting to TV...</div>
        <div class="skills-container" id="skillsContainer" style="display:none;">
            <button class="skill-btn" onclick="toggleSkill('fireball', this)">Fireball</button>
            <button class="skill-btn" onclick="toggleSkill('dash', this)">Dash</button>
            <button class="skill-btn" onclick="toggleSkill('heal', this)">Heal</button>
        </div>
        <button class="ready-btn" id="readyBtn" onclick="sendReady()">READY</button>
    </div>

    <!-- GAME OVER UI -->
    <div id="gameOverContainer">
        <h1 id="winStatusText" style="font-size: 40px; margin-bottom: 20px;"></h1>
        <button class="ready-btn visible" onclick="sendPlayAgain()" style="background-color: #29b6f6;">PLAY AGAIN</button>
    </div>

    <!-- CONTROLLER UI -->
    <div id="controllerContainer">
        <button class="quit-btn" onclick="sendQuit()">QUIT</button>
        <!-- Joystick -->
        <div id="joystick-zone">
            <div id="joystick-knob" class="snapping"></div>
        </div>
        
        <!-- Action Buttons -->
        <div class="action-pad">
            <div class="ctrl-btn action-btn btn-punch" data-action="punch">PUNCH</div>
            <div class="ctrl-btn action-btn btn-kick" data-action="kick">KICK</div>
            <div class="ctrl-btn action-btn btn-block" data-action="block">BLOCK</div>
            <div class="ctrl-btn skill-action-btn" id="skillBtn1" data-action="skill1">S1</div>
            <div class="ctrl-btn skill-action-btn" id="skillBtn2" data-action="skill2">S2</div>
        </div>
    </div>

    <script>
        const wsProtocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = wsProtocol + '//' + location.host + '/ws';
        const ws = new WebSocket(wsUrl);
        
        let playerNum = 0;
        let selectedSkills = [];
        let isGameStarted = false;
        
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.type === 'welcome') {
                playerNum = data.player;
                document.getElementById('joinTitle').innerText = 'Player ' + playerNum;
                document.getElementById('joinTitle').style.color = playerNum === 1 ? '#00e676' : '#29b6f6';
                document.getElementById('joinStatus').style.display = 'none';
                document.getElementById('playerNameInput').style.display = 'block';
                document.getElementById('joinBtn').style.display = 'block';
                document.getElementById('joinBtn').classList.add('visible');

                document.getElementById('title').innerText = 'Player ' + playerNum;
                document.getElementById('title').style.color = playerNum === 1 ? '#00e676' : '#29b6f6';
                document.getElementById('skillsContainer').style.display = 'flex';
                document.getElementById('status').innerText = 'Select exactly 2 skills';
            } else if (data.type === 'error') {
                document.getElementById('title').innerText = 'Error';
                document.getElementById('title').style.color = '#ff3d00';
                document.getElementById('status').innerText = data.message;
            } else if (data.type === 'game_start') {
                isGameStarted = true;
                
                // Switch UI from Lobby to Controller
                document.getElementById('lobbyContainer').style.display = 'none';
                document.getElementById('gameOverContainer').style.display = 'none';
                document.getElementById('controllerContainer').style.display = 'flex';
                
                // Configure skill buttons dynamically based on selections
                if (selectedSkills.length >= 2) {
                    const sb1 = document.getElementById('skillBtn1');
                    const sb2 = document.getElementById('skillBtn2');
                    sb1.innerText = selectedSkills[0].toUpperCase();
                    sb1.dataset.action = selectedSkills[0];
                    sb2.innerText = selectedSkills[1].toUpperCase();
                    sb2.dataset.action = selectedSkills[1];
                }
            } else if (data.type === 'game_over') {
                document.getElementById('controllerContainer').style.display = 'none';
                document.getElementById('gameOverContainer').style.display = 'flex';
                const statusText = document.getElementById('winStatusText');
                if (data.winner === playerNum) {
                    statusText.innerText = "YOU WIN! 🏆";
                    statusText.style.color = "#00e676";
                } else {
                    statusText.innerText = "YOU LOSE! 💀";
                    statusText.style.color = "#ff3d00";
                }
            }
        };

        ws.onclose = () => {
            showDisconnected();
        };

        function showDisconnected() {
            document.getElementById('lobbyContainer').style.display = 'flex';
            document.getElementById('controllerContainer').style.display = 'none';
            document.getElementById('gameOverContainer').style.display = 'none';
            document.getElementById('title').innerText = 'Disconnected';
            document.getElementById('status').innerText = 'Game session ended.';
            document.getElementById('skillsContainer').style.display = 'none';
            document.getElementById('readyBtn').style.display = 'none';
            document.getElementById('title').style.color = '#ff3d00';
        }

        // Lobby Logic
        function toggleSkill(skill, btn) {
            const index = selectedSkills.indexOf(skill);
            if (index > -1) {
                selectedSkills.splice(index, 1);
                btn.classList.remove('selected');
            } else {
                if (selectedSkills.length < 2) {
                    selectedSkills.push(skill);
                    btn.classList.add('selected');
                }
            }
            
            if (selectedSkills.length === 2) {
                document.getElementById('readyBtn').classList.add('visible');
            } else {
                document.getElementById('readyBtn').classList.remove('visible');
            }
        }
        
        function sendJoin() {
            const name = document.getElementById('playerNameInput').value || 'Player ' + playerNum;
            ws.send(JSON.stringify({ type: 'join', name: name }));
            document.getElementById('joinContainer').style.display = 'none';
            document.getElementById('lobbyContainer').style.display = 'flex';
        }

        function sendReady() {
            if (selectedSkills.length === 2) {
                ws.send(JSON.stringify({
                    type: 'ready',
                    skills: selectedSkills
                }));
                document.getElementById('skillsContainer').style.display = 'none';
                document.getElementById('readyBtn').style.display = 'none';
                document.getElementById('title').innerText = 'Ready!';
                document.getElementById('status').innerText = 'Waiting for the other player...';
                document.getElementById('status').style.color = '#00e676';
            }
        }

        function sendQuit() {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'quit' }));
                ws.close();
            }
            showDisconnected();
        }

        function sendPlayAgain() {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'play_again' }));
            }
        }

        // Controller Input Logic
        const joystickZone = document.getElementById('joystick-zone');
        const joystickKnob = document.getElementById('joystick-knob');
        let joyRadius = 0;
        let joyCenterX = 0;
        let joyCenterY = 0;
        let joyCurrentDir = null;

        const handleJoyStart = (e) => {
            e.preventDefault();
            const rect = joystickZone.getBoundingClientRect();
            joyRadius = rect.width / 2;
            joyCenterX = rect.left + joyRadius;
            joyCenterY = rect.top + joyRadius;
            joystickKnob.classList.remove('snapping');
            handleJoyMove(e);
        };

        const handleJoyMove = (e) => {
            e.preventDefault();
            if (!e.targetTouches[0]) return;
            const touch = e.targetTouches[0];
            let deltaX = touch.clientX - joyCenterX;
            let deltaY = touch.clientY - joyCenterY;
            const distance = Math.min(Math.sqrt(deltaX * deltaX + deltaY * deltaY), joyRadius);
            const angle = Math.atan2(deltaY, deltaX);

            const knobX = Math.cos(angle) * distance;
            const knobY = Math.sin(angle) * distance;
            joystickKnob.style.transform = 'translate(' + knobX + 'px, ' + knobY + 'px)';

            let newDir = null;
            if (distance > 20) { // Deadzone
                if (Math.abs(deltaX) > Math.abs(deltaY)) {
                    newDir = deltaX > 0 ? 'right' : 'left';
                } else {
                    newDir = deltaY > 0 ? 'down' : 'up';
                }
            }

            if (newDir !== joyCurrentDir) {
                if (joyCurrentDir && ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: 'input', action: joyCurrentDir, state: 'released' }));
                }
                joyCurrentDir = newDir;
                if (joyCurrentDir && ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: 'input', action: joyCurrentDir, state: 'pressed' }));
                }
            }
        };

        const handleJoyEnd = (e) => {
            e.preventDefault();
            joystickKnob.classList.add('snapping');
            joystickKnob.style.transform = `translate(0px, 0px)`;
            if (joyCurrentDir) {
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: 'input', action: joyCurrentDir, state: 'released' }));
                }
                joyCurrentDir = null;
            }
        };

        joystickZone.addEventListener('touchstart', handleJoyStart, {passive: false});
        joystickZone.addEventListener('touchmove', handleJoyMove, {passive: false});
        joystickZone.addEventListener('touchend', handleJoyEnd, {passive: false});
        joystickZone.addEventListener('touchcancel', handleJoyEnd, {passive: false});
        joystickZone.addEventListener('mouseleave', handleJoyEnd, {passive: false});

        function handleTouch(e, state) {
            e.preventDefault(); // Prevents 300ms delay, scrolling, and zooming
            const target = e.currentTarget;
            const action = target.dataset.action;
            
            // Skill Cooldown Logic
            const isSkill = target.classList.contains('skill-action-btn');
            if (isSkill && state === 'pressed') {
                if (target.classList.contains('skill-cooldown')) return; // Ignore if on cooldown
                
                target.classList.add('skill-cooldown');
                setTimeout(() => {
                    target.classList.remove('skill-cooldown');
                }, 2000);
            }

            // Visual State Update
            if (state === 'pressed') {
                target.classList.add('active');
            } else {
                target.classList.remove('active');
            }

            // Send WebSocket Message
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'input',
                    action: action,
                    state: state
                }));
            }
        }

        // Bind touch events to all controller buttons
        document.querySelectorAll('.ctrl-btn').forEach(btn => {
            btn.addEventListener('touchstart', (e) => handleTouch(e, 'pressed'), {passive: false});
            btn.addEventListener('touchend', (e) => handleTouch(e, 'released'), {passive: false});
            btn.addEventListener('touchcancel', (e) => handleTouch(e, 'released'), {passive: false});
            btn.addEventListener('mouseleave', (e) => handleTouch(e, 'released'), {passive: false});
        });

        // Global fallback to release all stuck inputs
        const globalRelease = () => {
            document.querySelectorAll('.ctrl-btn.active').forEach(btn => {
                btn.classList.remove('active');
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify({
                        type: 'input',
                        action: btn.dataset.action,
                        state: 'released'
                    }));
                }
            });
        };
        window.addEventListener('touchend', globalRelease);
        window.addEventListener('touchcancel', globalRelease);
    </script>
</body>
</html>
''';
// --------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]).then((_) {
    runApp(const AndroidTVGameApp());
  });
}

class AndroidTVGameApp extends StatelessWidget {
  const AndroidTVGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Multiplayer TV Game',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const ServerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum GameState { waiting, starting }

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  String _ipAddress = "Loading...";
HttpServer? _server;

  GameState _gameState = GameState.waiting;
  ShadowFightGame? _game;
  
  // Track connections using WebSocketChannel as key to uniquely identify sessions
  final Map<WebSocketChannel, int> _connectedPlayers = {};
  final Map<int, List<String>> _playerSkills = {};
  final Map<int, String> _playerNames = {};

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    try {
      final ip = await _getLocalIpAddress();
      if (!mounted) return;
      
      setState(() {
        _ipAddress = ip ?? "Could not find IP";
      });

      if (ip != null) {
        await _startHttpServer(ip);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ipAddress = "Error starting server";
      });
      debugPrint('Server initialization error: $e');
    }
  }

  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      
      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching IP address: $e");
    }
    return null;
  }

  Future<void> _startHttpServer(String ip) async {
    var wsHandler = webSocketHandler((WebSocketChannel webSocket, String? protocol) {
      int? playerId;

      // Assign player 1 or 2
      if (!_connectedPlayers.containsValue(1)) {
        playerId = 1;
      } else if (!_connectedPlayers.containsValue(2)) {
        playerId = 2;
      }

      if (playerId == null) {
        // Reject 3rd connection
        webSocket.sink.add(jsonEncode({'type': 'error', 'message': 'Lobby is full'}));
        webSocket.sink.close();
        return;
      }

      setState(() {
        _connectedPlayers[webSocket] = playerId!;
      });

      debugPrint('Player $playerId connected!');
      webSocket.sink.add(jsonEncode({'type': 'welcome', 'player': playerId}));

      // Listen for messages
      void handleDisconnect() {
        _connectedPlayers.remove(webSocket);
        _playerSkills.remove(playerId);
        _playerNames.remove(playerId);

        if (_connectedPlayers.isEmpty || (_game != null && _game!.isGameOver)) {
          _resetToLobby();
        } else if (_game != null) {
          final fighter = playerId == 1 ? _game!.player1 : _game!.player2;
          fighter.current = FighterState.idle;
          fighter.velocity.setZero();
          fighter.leftPressed = false;
          fighter.rightPressed = false;
          fighter.crouchPressed = false;
        } else {
          _resetToLobby();
        }
      }

      webSocket.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          
          if (data['type'] == 'join') {
            final name = data['name']?.toString() ?? 'Player $playerId';
            _playerNames[playerId!] = name;
            
            if (_game != null) {
              _game!.updatePlayerNames(
                _playerNames[1] ?? "PLAYER 1",
                _playerNames[2] ?? "PLAYER 2"
              );
            }
          } else if (data['type'] == 'ready') {
            setState(() {
              _playerSkills[playerId!] = List<String>.from(data['skills']);
              debugPrint('Player $playerId is ready with skills: ${_playerSkills[playerId]}');
              
              // Check if both players are ready
              if (_playerSkills.containsKey(1) && _playerSkills.containsKey(2)) {
                _gameState = GameState.starting;
                _game = ShadowFightGame(
                  onGameOver: (winner) {
                    final msg = jsonEncode({'type': 'game_over', 'winner': winner});
                    for (var wsClient in _connectedPlayers.keys) {
                      wsClient.sink.add(msg);
                    }
                  },
                  player1Name: _playerNames[1] ?? "PLAYER 1",
                  player2Name: _playerNames[2] ?? "PLAYER 2",
                );
                
                // Broadcast game_start to both players
                final startMsg = jsonEncode({'type': 'game_start'});
                for (var wsClient in _connectedPlayers.keys) {
                  wsClient.sink.add(startMsg);
                }
              }
            });
          } else if (data['type'] == 'input') {
            // Log incoming inputs from the Web Controller
            final action = data['action'];
            final state = data['state'];
            debugPrint('Player $playerId: $action $state');
            
            if (_gameState == GameState.starting && _game != null) {
              _game!.handleInput(playerId!, action, state);
            }
          } else if (data['type'] == 'play_again') {
            if (_game != null && _game!.isGameOver) {
              _game!.resetGame();
              final startMsg = jsonEncode({'type': 'game_start'});
              for (var wsClient in _connectedPlayers.keys) {
                wsClient.sink.add(startMsg);
              }
            }
          } else if (data['type'] == 'quit') {
            _resetToLobby();
          }
        } catch (e) {
          debugPrint('Error parsing message from Player $playerId: $e');
        }
      }, onDone: () {
        debugPrint('Player $playerId disconnected!');
        handleDisconnect();
      }, onError: (error) {
        debugPrint('Player $playerId error: $error');
        handleDisconnect();
      });
    });

    FutureOr<shelf.Response> router(shelf.Request request) {
      if (request.url.path.isEmpty || request.url.path == '/') {
        return shelf.Response.ok(clientHtml, headers: {'content-type': 'text/html'});
      } else if (request.url.path == 'ws') {
        return wsHandler(request);
      }
      return shelf.Response.notFound('Not found');
    }

    _server = await shelf_io.serve(router, ip, 8080);
    debugPrint('Server running on http://$ip:8080');
  }

  void _resetToLobby() {
    if (!mounted) return;
    setState(() {
      for (var ws in _connectedPlayers.keys) {
        ws.sink.close();
      }
      _connectedPlayers.clear();
      _playerSkills.clear();
      _playerNames.clear();
      _gameState = GameState.waiting;
      _game = null;
    });
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameState == GameState.starting) {
      return _buildGameStartingUi();
    }
    return _buildWaitingUi();
  }

  Widget _buildWaitingUi() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Connect your phones to:',
              style: TextStyle(
                fontSize: 32,
                color: Colors.white70,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _ipAddress == "Loading..." || _ipAddress.startsWith("Error") || _ipAddress == "Could not find IP"
                  ? _ipAddress
                  : 'http://$_ipAddress:8080',
              style: const TextStyle(
                fontSize: 64,
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _playerStatusIndicator(1),
                const SizedBox(width: 60),
                _playerStatusIndicator(2),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Waiting for players to join and select skills...',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerStatusIndicator(int playerId) {
    bool isConnected = _connectedPlayers.containsValue(playerId);
    bool isReady = _playerSkills.containsKey(playerId);
    
    Color color = Colors.grey;
    String status = "Waiting to connect...";
    
    if (isReady) {
      color = Colors.greenAccent;
      status = "Ready!";
    } else if (isConnected) {
      color = Colors.orangeAccent;
      status = "Selecting Skills...";
    }

    return Column(
      children: [
        Text(
          'Player $playerId',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isConnected ? (playerId == 1 ? Colors.greenAccent : Colors.lightBlue) : Colors.white38,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status,
          style: TextStyle(
            fontSize: 20,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGameStartingUi() {
    return Scaffold(
      body: GameWidget(
        game: _game!,
      ),
    );
  }
}
