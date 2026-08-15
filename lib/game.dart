import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class ShadowFightGame extends FlameGame {
  late final Fighter player1;
  late final Fighter player2;

  @override
  Color backgroundColor() => const Color(0xFF1E1E1E); // Dark night sky

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Ground
    add(GroundComponent());

    // Player 1
    player1 = Fighter(
      playerId: 1,
      eyeColor: Colors.redAccent,
      startPosition: Vector2(size.x * 0.2, size.y - 40 - 150),
      facingRight: true,
    );
    add(player1);

    // Player 2
    player2 = Fighter(
      playerId: 2,
      eyeColor: Colors.blueAccent,
      startPosition: Vector2(size.x * 0.8, size.y - 40 - 150),
      facingRight: false,
    );
    add(player2);
  }

  void handleInput(int playerId, String action, String state) {
    if (playerId == 1) {
      player1.handleInput(action, state);
    } else if (playerId == 2) {
      player2.handleInput(action, state);
    }
  }
}

class GroundComponent extends PositionComponent with HasGameRef<ShadowFightGame> {
  static const double groundHeight = 40;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(gameRef.size.x, groundHeight);
    position = Vector2(0, gameRef.size.y - groundHeight);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2C2C2C));
  }
  
  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size = Vector2(gameSize.x, groundHeight);
    position = Vector2(0, gameSize.y - groundHeight);
  }
}

class Fighter extends PositionComponent with HasGameRef<ShadowFightGame> {
  final int playerId;
  final Color eyeColor;
  bool facingRight;
  
  // Physics constants
  static const double moveSpeed = 400.0;
  static const double jumpForce = -700.0;
  static const double gravity = 1500.0;

  Vector2 velocity = Vector2.zero();
  bool isGrounded = false;
  
  // Input tracking
  bool leftPressed = false;
  bool rightPressed = false;

  Fighter({
    required this.playerId,
    required this.eyeColor,
    required Vector2 startPosition,
    required this.facingRight,
  }) : super(position: startPosition, size: Vector2(60, 150));

  void handleInput(String action, String state) {
    final bool isPressed = state == 'pressed';
    
    switch (action) {
      case 'left':
        leftPressed = isPressed;
        break;
      case 'right':
        rightPressed = isPressed;
        break;
      case 'up':
        if (isPressed && isGrounded) {
          velocity.y = jumpForce;
          isGrounded = false;
        }
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Apply horizontal velocity based on input
    if (leftPressed && !rightPressed) {
      velocity.x = -moveSpeed;
    } else if (rightPressed && !leftPressed) {
      velocity.x = moveSpeed;
    } else {
      velocity.x = 0;
    }

    // Apply gravity
    if (!isGrounded) {
      velocity.y += gravity * dt;
    }

    // Apply velocity to position
    position += velocity * dt;

    // Floor collision
    final groundY = gameRef.size.y - GroundComponent.groundHeight;
    if (position.y + size.y >= groundY) {
      position.y = groundY - size.y;
      velocity.y = 0;
      isGrounded = true;
    } else {
      isGrounded = false;
    }

    // Screen boundaries
    if (position.x < 0) {
      position.x = 0;
    } else if (position.x + size.x > gameRef.size.x) {
      position.x = gameRef.size.x - size.x;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Body (Shadow)
    final bodyPaint = Paint()..color = Colors.black;
    canvas.drawRect(size.toRect(), bodyPaint);

    // Eyes
    final eyePaint = Paint()..color = eyeColor;
    
    // Position eyes based on facing direction
    final eyeX = facingRight ? size.x - 20.0 : 5.0;
    final eyeY = 20.0;
    final eyeWidth = 15.0;
    final eyeHeight = 5.0;
    
    canvas.drawRect(Rect.fromLTWH(eyeX, eyeY, eyeWidth, eyeHeight), eyePaint);
  }
}
