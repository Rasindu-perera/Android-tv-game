import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force landscape orientation for TV
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

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  String _ipAddress = "Loading...";
  HttpServer? _server;

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
        await _startWebSocketServer(ip);
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
      // List all network interfaces
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      
      for (var interface in interfaces) {
        // Find the first IPv4 address that is not loopback
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

  Future<void> _startWebSocketServer(String ip) async {
    var handler = webSocketHandler((WebSocketChannel webSocket) {
      debugPrint('New client connected!');

      webSocket.stream.listen((message) {
        debugPrint('Message from client: $message');
      }, onDone: () {
        debugPrint('Client disconnected!');
      }, onError: (error) {
        debugPrint('Client error: $error');
      });
    });

    // Start the server in the background
    _server = await shelf_io.serve(handler, ip, 8080);
    debugPrint('WebSocket Server running on ws://$ip:8080');
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const CircularProgressIndicator(
              color: Colors.greenAccent,
              strokeWidth: 3,
            ),
            const SizedBox(height: 30),
            const Text(
              'Waiting for players...',
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
}
