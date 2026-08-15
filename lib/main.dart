import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// --------------------------------------------------------
// HTML/JS/CSS Payload for the phone client
// --------------------------------------------------------
const String clientHtml = '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, orientation=landscape">
    <title>TV Game Controller</title>
    <style>
        body {
            background-color: #121212;
            color: #ffffff;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            overflow: hidden;
            user-select: none;
        }
        h1 { margin-top: 10px; font-size: 28px; color: #00e676; margin-bottom: 5px; }
        .skills-container {
            display: flex;
            gap: 20px;
            margin-top: 20px;
        }
        .skill-btn {
            background-color: #333;
            color: white;
            border: 2px solid #555;
            border-radius: 12px;
            padding: 20px 40px;
            font-size: 20px;
            cursor: pointer;
            transition: all 0.2s;
            text-transform: uppercase;
            font-weight: bold;
        }
        .skill-btn.selected {
            background-color: #00e676;
            color: #000;
            border-color: #00e676;
            transform: scale(1.05);
            box-shadow: 0 0 15px rgba(0, 230, 118, 0.5);
        }
        .ready-btn {
            margin-top: 30px;
            background-color: #ff3d00;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 15px 50px;
            font-size: 22px;
            font-weight: bold;
            cursor: pointer;
            visibility: hidden;
            transition: background-color 0.2s;
        }
        .ready-btn:active {
            background-color: #dd2c00;
        }
        .ready-btn.visible { visibility: visible; }
        #status { margin-top: 5px; color: #aaa; font-size: 16px; }
    </style>
</head>
<body>
    <h1 id="title">Connecting...</h1>
    <div id="status">Connecting to TV...</div>
    <div class="skills-container" id="skillsContainer" style="display:none;">
        <button class="skill-btn" onclick="toggleSkill('fireball', this)">Fireball</button>
        <button class="skill-btn" onclick="toggleSkill('dash', this)">Dash</button>
        <button class="skill-btn" onclick="toggleSkill('heal', this)">Heal</button>
    </div>
    <button class="ready-btn" id="readyBtn" onclick="sendReady()">READY</button>

    <script>
        // Connect to WebSocket server on the same host but at /ws path
        const wsProtocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = wsProtocol + '//' + location.host + '/ws';
        const ws = new WebSocket(wsUrl);
        
        let playerNum = 0;
        let selectedSkills = [];
        
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.type === 'welcome') {
                playerNum = data.player;
                document.getElementById('title').innerText = 'Player ' + playerNum;
                document.getElementById('title').style.color = playerNum === 1 ? '#00e676' : '#29b6f6';
                document.getElementById('skillsContainer').style.display = 'flex';
                document.getElementById('status').innerText = 'Select exactly 2 skills';
            } else if (data.type === 'error') {
                document.getElementById('title').innerText = 'Error';
                document.getElementById('title').style.color = '#ff3d00';
                document.getElementById('status').innerText = data.message;
            }
        };

        ws.onclose = () => {
            document.getElementById('title').innerText = 'Disconnected';
            document.getElementById('status').innerText = 'Lost connection to TV.';
            document.getElementById('skillsContainer').style.display = 'none';
            document.getElementById('readyBtn').style.display = 'none';
        };

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
  
  // Track connections using WebSocketChannel as key to uniquely identify sessions
  final Map<WebSocketChannel, int> _connectedPlayers = {};
  final Map<int, List<String>> _playerSkills = {};

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
    // 1. WebSocket Handler
    var wsHandler = webSocketHandler((WebSocketChannel webSocket) {
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
      webSocket.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'ready') {
            setState(() {
              _playerSkills[playerId!] = List<String>.from(data['skills']);
              debugPrint('Player $playerId is ready with skills: ${_playerSkills[playerId]}');
              
              // Check if both players are ready
              if (_playerSkills.containsKey(1) && _playerSkills.containsKey(2)) {
                _gameState = GameState.starting;
              }
            });
          }
        } catch (e) {
          debugPrint('Error parsing message from Player $playerId: $e');
        }
      }, onDone: () {
        debugPrint('Player $playerId disconnected!');
        setState(() {
          _connectedPlayers.remove(webSocket);
          _playerSkills.remove(playerId);
          _gameState = GameState.waiting; // Revert state if a player disconnects
        });
      }, onError: (error) {
        debugPrint('Player $playerId error: $error');
      });
    });

    // 2. HTTP Router
    FutureOr<shelf.Response> router(shelf.Request request) {
      if (request.url.path.isEmpty || request.url.path == '/') {
        // Serve the HTML string
        return shelf.Response.ok(clientHtml, headers: {'content-type': 'text/html'});
      } else if (request.url.path == 'ws') {
        // Upgrade to WebSocket
        return wsHandler(request);
      }
      return shelf.Response.notFound('Not found');
    }

    // 3. Start the server
    _server = await shelf_io.serve(router, ip, 8080);
    debugPrint('Server running on http://$ip:8080');
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Game Starting...',
              style: TextStyle(
                fontSize: 64,
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _playerSkillCard(1, _playerSkills[1] ?? []),
                _playerSkillCard(2, _playerSkills[2] ?? []),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _playerSkillCard(int playerId, List<String> skills) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: playerId == 1 ? Colors.greenAccent : Colors.lightBlue,
          width: 3,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Player $playerId',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: playerId == 1 ? Colors.greenAccent : Colors.lightBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Selected Skills',
            style: TextStyle(fontSize: 20, color: Colors.white70),
          ),
          const SizedBox(height: 15),
          ...skills.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  s.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
