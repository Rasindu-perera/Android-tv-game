import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class ShadowFightGame extends FlameGame {
  late final Fighter player1;
  late final Fighter player2;
  
  bool isGameOver = false;
  double gameOverTimer = 0;

  @override
  Color backgroundColor() => const Color(0xFF1E1E1E);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    add(GroundComponent());

    player1 = Fighter(
      playerId: 1,
      eyeColor: Colors.redAccent,
      startPosition: Vector2(size.x * 0.2, size.y - 40 - 150),
      facingRight: true,
    );
    add(player1);

    player2 = Fighter(
      playerId: 2,
      eyeColor: Colors.blueAccent,
      startPosition: Vector2(size.x * 0.8, size.y - 40 - 150),
      facingRight: false,
    );
    add(player2);
  }

  void handleInput(int playerId, String action, String state) {
    if (isGameOver) return;
    
    if (playerId == 1) {
      player1.handleInput(action, state);
    } else if (playerId == 2) {
      player2.handleInput(action, state);
    }
  }

  void spawnFireball(Fighter shooter) {
    final startX = shooter.facingRight ? shooter.position.x + shooter.size.x : shooter.position.x - 30;
    final startY = shooter.position.y + 40;
    add(Fireball(
      ownerId: shooter.playerId,
      movingRight: shooter.facingRight,
      startPosition: Vector2(startX, startY),
    ));
  }

  @override
  void update(double dt) {
    if (isGameOver) {
      gameOverTimer -= dt;
      if (gameOverTimer <= 0) resetGame();
      return; 
    }

    super.update(dt);

    // Auto-face opponent
    if (player1.position.x < player2.position.x) {
      player1.facingRight = true;
      player2.facingRight = false;
    } else {
      player1.facingRight = false;
      player2.facingRight = true;
    }

    // Check Melee Collisions
    _checkMeleeHit(player1, player2);
    _checkMeleeHit(player2, player1);

    // Check Game Over
    if (player1.health <= 0 || player2.health <= 0) {
      isGameOver = true;
      gameOverTimer = 3.0;
    }
  }

  void _checkMeleeHit(Fighter attacker, Fighter defender) {
    if (attacker.isAttacking && !attacker.attackHasHit) {
      final aRect = attacker.absoluteAttackRect;
      if (aRect != null && aRect.overlaps(defender.absoluteRect)) {
        defender.health -= attacker.attackDamage;
        attacker.attackHasHit = true;
      }
    }
  }

  void resetGame() {
    isGameOver = false;
    player1.health = 100;
    player2.health = 100;
    player1.position = Vector2(size.x * 0.2, size.y - 40 - 150);
    player2.position = Vector2(size.x * 0.8, size.y - 40 - 150);
    player1.velocity = Vector2.zero();
    player2.velocity = Vector2.zero();
    
    children.whereType<Fireball>().forEach((f) => f.removeFromParent());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Health Bars
    final p1Width = (player1.health / 100).clamp(0.0, 1.0) * 300;
    final p2Width = (player2.health / 100).clamp(0.0, 1.0) * 300;

    canvas.drawRect(Rect.fromLTWH(50, 30, 300, 20), Paint()..color = Colors.red.withOpacity(0.3));
    canvas.drawRect(Rect.fromLTWH(50, 30, p1Width, 20), Paint()..color = Colors.redAccent);

    canvas.drawRect(Rect.fromLTWH(size.x - 350, 30, 300, 20), Paint()..color = Colors.blue.withOpacity(0.3));
    canvas.drawRect(Rect.fromLTWH(size.x - 50 - p2Width, 30, p2Width, 20), Paint()..color = Colors.blueAccent);

    // Game Over UI
    if (isGameOver) {
      final winner = player1.health > player2.health ? "Player 1" : "Player 2";
      final text = player1.health <= 0 && player2.health <= 0 ? "Draw!" : "$winner Wins!";
      
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2));
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

class Fireball extends PositionComponent with HasGameRef<ShadowFightGame> {
  final int ownerId;
  final bool movingRight;
  final double speed = 800.0;
  final double damage = 20.0;

  Fireball({
    required this.ownerId,
    required this.movingRight,
    required Vector2 startPosition,
  }) : super(position: startPosition, size: Vector2(30, 20));

  @override
  void update(double dt) {
    super.update(dt);
    position.x += (movingRight ? speed : -speed) * dt;

    if (position.x < -100 || position.x > gameRef.size.x + 100) {
      removeFromParent();
      return;
    }

    final myRect = Rect.fromLTWH(position.x, position.y, size.x, size.y);
    final opponent = ownerId == 1 ? gameRef.player2 : gameRef.player1;
    
    if (myRect.overlaps(opponent.absoluteRect)) {
      opponent.health -= damage;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), Paint()..color = Colors.orangeAccent);
  }
}

class Fighter extends PositionComponent with HasGameRef<ShadowFightGame> {
  final int playerId;
  final Color eyeColor;
  bool facingRight;
  
  double health = 100;
  
  // Physics
  static const double moveSpeed = 400.0;
  static const double jumpForce = -700.0;
  static const double gravity = 1500.0;

  Vector2 velocity = Vector2.zero();
  bool isGrounded = false;
  
  // Input tracking
  bool leftPressed = false;
  bool rightPressed = false;

  // Combat state
  bool isAttacking = false;
  double attackTimer = 0;
  Rect? attackRect;
  double attackDamage = 0;
  bool attackHasHit = false;

  bool isDashing = false;
  double dashTimer = 0;

  Fighter({
    required this.playerId,
    required this.eyeColor,
    required Vector2 startPosition,
    required this.facingRight,
  }) : super(position: startPosition, size: Vector2(60, 150));

  Rect get absoluteRect => Rect.fromLTWH(position.x, position.y, size.x, size.y);
  Rect? get absoluteAttackRect {
    if (!isAttacking || attackRect == null) return null;
    return attackRect!.translate(position.x, position.y);
  }

  void handleInput(String action, String state) {
    final bool isPressed = state == 'pressed';
    
    switch (action) {
      case 'left': leftPressed = isPressed; break;
      case 'right': rightPressed = isPressed; break;
      case 'up':
        if (isPressed && isGrounded) {
          velocity.y = jumpForce;
          isGrounded = false;
        }
        break;
      case 'punch':
        if (isPressed && !isAttacking) _startAttack(10, 0.2, 40, 20);
        break;
      case 'kick':
        if (isPressed && !isAttacking) _startAttack(15, 0.3, 50, 20);
        break;
      case 'fireball':
        if (isPressed) gameRef.spawnFireball(this);
        break;
      case 'dash':
        if (isPressed && !isDashing) {
          isDashing = true;
          dashTimer = 0.2;
          velocity.x = facingRight ? 1500 : -1500;
        }
        break;
      case 'heal':
        if (isPressed) health = (health + 30).clamp(0, 100);
        break;
    }
  }

  void _startAttack(double damage, double duration, double w, double h) {
    isAttacking = true;
    attackTimer = duration;
    attackDamage = damage;
    attackHasHit = false;
    
    final rectX = facingRight ? size.x : -w;
    final rectY = 40.0;
    attackRect = Rect.fromLTWH(rectX, rectY, w, h);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isDashing) {
      dashTimer -= dt;
      if (dashTimer <= 0) isDashing = false;
    } else {
      if (leftPressed && !rightPressed) {
        velocity.x = -moveSpeed;
      } else if (rightPressed && !leftPressed) {
        velocity.x = moveSpeed;
      } else {
        velocity.x = 0;
      }
    }

    if (!isGrounded) {
      velocity.y += gravity * dt;
    }

    position += velocity * dt;

    final groundY = gameRef.size.y - GroundComponent.groundHeight;
    if (position.y + size.y >= groundY) {
      position.y = groundY - size.y;
      velocity.y = 0;
      isGrounded = true;
    } else {
      isGrounded = false;
    }

    if (position.x < 0) {
      position.x = 0;
    } else if (position.x + size.x > gameRef.size.x) {
      position.x = gameRef.size.x - size.x;
    }

    if (isAttacking) {
      attackTimer -= dt;
      if (attackTimer <= 0) {
        isAttacking = false;
        attackRect = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    final bodyPaint = Paint()..color = Colors.black;
    canvas.drawRect(size.toRect(), bodyPaint);

    final eyePaint = Paint()..color = eyeColor;
    final eyeX = facingRight ? size.x - 20.0 : 5.0;
    canvas.drawRect(Rect.fromLTWH(eyeX, 20.0, 15.0, 5.0), eyePaint);

    if (isAttacking && attackRect != null) {
      final hitPaint = Paint()..color = Colors.white.withOpacity(0.7);
      canvas.drawRect(attackRect!, hitPaint);
    }
  }
}
