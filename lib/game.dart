import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

// -- Cached Paints for Zero-Allocation Rendering --
final Paint _groundPaint = Paint()..color = const Color(0xFF2C2C2C);
final Paint _p1HealthBgPaint = Paint()..color = Colors.red.withOpacity(0.3);
final Paint _p1HealthPaint = Paint()..color = Colors.redAccent;
final Paint _p2HealthBgPaint = Paint()..color = Colors.blue.withOpacity(0.3);
final Paint _p2HealthPaint = Paint()..color = Colors.blueAccent;
final Paint _fireballPaint = Paint()..color = Colors.orangeAccent;
final Paint _hitboxPaint = Paint()..color = Colors.white.withOpacity(0.7);

enum FighterState { idle, run, jump, attack, kick, hurt, crouch }

class ShadowFightGame extends FlameGame {
  late final Fighter player1;
  late final Fighter player2;
  
  bool isGameOver = false;
  double gameOverTimer = 0;

  late final TextPainter p1WinText;
  late final TextPainter p2WinText;
  late final TextPainter drawText;

  @override
  Color backgroundColor() => const Color(0xFF1E1E1E);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Random Background
    final bgName = Random().nextBool() ? 'bg1.png' : 'bg2.png';
    final bgSprite = await loadSprite(bgName);
    add(SpriteComponent(
      sprite: bgSprite,
      size: size,
    ));

    // Cache TextPainters
    p1WinText = _buildText("Player 1 Wins!");
    p2WinText = _buildText("Player 2 Wins!");
    drawText = _buildText("Draw!");

    add(GroundComponent());

    player1 = Fighter(
      playerId: 1,
      eyeColor: Colors.redAccent,
      startPosition: Vector2(size.x * 0.2, size.y - 40), // Ground Y
      facingRight: true,
    );
    add(player1);

    player2 = Fighter(
      playerId: 2,
      eyeColor: Colors.blueAccent,
      startPosition: Vector2(size.x * 0.8, size.y - 40),
      facingRight: false,
    );
    add(player2);
  }

  TextPainter _buildText(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
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
    final startX = shooter.facingRight ? shooter.position.x + shooter.size.x / 2 : shooter.position.x - shooter.size.x / 2 - 30;
    final startY = shooter.position.y - shooter.size.y / 2;
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

    if (player1.position.x < player2.position.x) {
      if (!player1.facingRight) {
        player1.facingRight = true;
        player1.flipHorizontallyAroundCenter();
      }
      if (player2.facingRight) {
        player2.facingRight = false;
        player2.flipHorizontallyAroundCenter();
      }
    } else {
      if (player1.facingRight) {
        player1.facingRight = false;
        player1.flipHorizontallyAroundCenter();
      }
      if (!player2.facingRight) {
        player2.facingRight = true;
        player2.flipHorizontallyAroundCenter();
      }
    }

    _checkMeleeHit(player1, player2);
    _checkMeleeHit(player2, player1);

    if (player1.health <= 0 || player2.health <= 0) {
      isGameOver = true;
      gameOverTimer = 3.0;
    }
  }

  void _checkMeleeHit(Fighter attacker, Fighter defender) {
    if (attacker.isAttacking && !attacker.attackHasHit) {
      final aRect = attacker.absoluteAttackRect;
      if (aRect != null && aRect.overlaps(defender.absoluteRect)) {
        defender.takeDamage(attacker.attackDamage);
        attacker.attackHasHit = true;
      }
    }
  }

  void resetGame() {
    isGameOver = false;
    player1.health = 100;
    player2.health = 100;
    player1.current = FighterState.idle;
    player2.current = FighterState.idle;
    
    player1.position.setValues(size.x * 0.2, size.y - 40);
    player2.position.setValues(size.x * 0.8, size.y - 40);
    player1.velocity.setZero();
    player2.velocity.setZero();
    
    children.whereType<Fireball>().forEach((f) => f.removeFromParent());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final p1Width = (player1.health / 100).clamp(0.0, 1.0) * 300;
    final p2Width = (player2.health / 100).clamp(0.0, 1.0) * 300;

    canvas.drawRect(Rect.fromLTWH(50, 30, 300, 20), _p1HealthBgPaint);
    canvas.drawRect(Rect.fromLTWH(50, 30, p1Width, 20), _p1HealthPaint);

    canvas.drawRect(Rect.fromLTWH(size.x - 350, 30, 300, 20), _p2HealthBgPaint);
    canvas.drawRect(Rect.fromLTWH(size.x - 50 - p2Width, 30, p2Width, 20), _p2HealthPaint);

    if (isGameOver) {
      TextPainter activeText;
      if (player1.health <= 0 && player2.health <= 0) {
        activeText = drawText;
      } else if (player1.health > player2.health) {
        activeText = p1WinText;
      } else {
        activeText = p2WinText;
      }
      activeText.paint(canvas, Offset((size.x - activeText.width) / 2, (size.y - activeText.height) / 2));
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
    canvas.drawRect(size.toRect(), _groundPaint);
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
      opponent.takeDamage(damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), _fireballPaint);
  }
}

class Fighter extends SpriteAnimationGroupComponent<FighterState> with HasGameRef<ShadowFightGame> {
  final int playerId;
  bool facingRight;
  
  double health = 100;
  
  static const double moveSpeed = 400.0;
  static const double jumpForce = -700.0;
  static const double gravity = 1500.0;

  Vector2 velocity = Vector2.zero();
  bool isGrounded = false;
  
  bool leftPressed = false;
  bool rightPressed = false;
  bool crouchPressed = false;

  bool isAttacking = false;
  Rect? attackRect;
  double attackDamage = 0;
  bool attackHasHit = false;

  bool isDashing = false;
  double dashTimer = 0;
  
  final Color eyeColor;

  Fighter({
    required this.playerId,
    required this.eyeColor,
    required Vector2 startPosition,
    required this.facingRight,
  }) : super(
         position: startPosition, 
         size: Vector2(100, 150),
         anchor: Anchor.bottomCenter, // Sets logical position to be the feet
       );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Tint for multiplayer distinguishing
    paint = Paint()..colorFilter = ColorFilter.mode(eyeColor.withOpacity(0.5), BlendMode.srcATop);

    if (!facingRight) {
      flipHorizontallyAroundCenter();
    }

    // Parallel load animation frames
    Future<SpriteAnimation> loadAnimation(List<String> paths, {bool loop = true}) async {
      final sprites = await Future.wait(paths.map((p) => gameRef.loadSprite(p)));
      return SpriteAnimation.spriteList(sprites, stepTime: 0.1, loop: loop);
    }

    final idleFrames = List.generate(1, (i) => 'ninja/_${i + 1}.png');
    final runFrames = List.generate(11, (i) => 'ninja/_${i + 8}.png');
    final jumpFrames = List.generate(5, (i) => 'ninja/_${i + 19}.png');
    final attackFrames = List.generate(4, (i) => 'ninja/_${i + 23}.png');
    final kickFrames = List.generate(2, (i) => 'ninja/_${i + 27}.png');
    final hurtFrames = List.generate(5, (i) => 'ninja/_${i + 29}.png');

    final idleAnim = await loadAnimation(idleFrames);
    final runAnim = await loadAnimation(runFrames);
    final jumpAnim = await loadAnimation(jumpFrames);
    final attackAnim = await loadAnimation(attackFrames, loop: false);
    final kickAnim = await loadAnimation(kickFrames, loop: false);
    final hurtAnim = await loadAnimation(hurtFrames, loop: false);

    animations = {
      FighterState.idle: idleAnim,
      FighterState.run: runAnim,
      FighterState.jump: jumpAnim,
      FighterState.attack: attackAnim,
      FighterState.kick: kickAnim,
      FighterState.hurt: hurtAnim,
      FighterState.crouch: idleAnim, // fallback
    };

    current = FighterState.idle;
  }

  Rect get absoluteRect {
    final actualHeight = size.y * scale.y;
    return Rect.fromLTWH(position.x - size.x / 2, position.y - actualHeight, size.x, actualHeight);
  }

  Rect? get absoluteAttackRect {
    if (!isAttacking || attackRect == null) return null;
    return attackRect!.translate(position.x - size.x / 2, position.y - size.y);
  }

  void handleInput(String action, String state) {
    if (current == FighterState.hurt) return;
    final bool isPressed = state == 'pressed';
    
    switch (action) {
      case 'left': leftPressed = isPressed; break;
      case 'right': rightPressed = isPressed; break;
      case 'down': crouchPressed = isPressed; break;
      case 'up':
        if (isPressed && isGrounded && !isAttacking) {
          velocity.y = jumpForce;
          isGrounded = false;
          current = FighterState.jump;
        }
        break;
      case 'punch':
        if (isPressed && !isAttacking && isGrounded) _startAttack(10, 40, 20, FighterState.attack);
        break;
      case 'kick':
        if (isPressed && !isAttacking && isGrounded) _startAttack(15, 50, 20, FighterState.kick);
        break;
      case 'fireball':
        if (isPressed && !isAttacking && isGrounded) {
          _startAttack(0, 0, 0, FighterState.attack); 
          gameRef.spawnFireball(this);
        }
        break;
      case 'dash':
        if (isPressed && !isDashing && isGrounded && !isAttacking) {
          isDashing = true;
          dashTimer = 0.2;
          velocity.x = facingRight ? 1500 : -1500;
          current = FighterState.run;
        }
        break;
      case 'heal':
        if (isPressed && isGrounded && !isAttacking) {
          health = (health + 30).clamp(0, 100);
        }
        break;
    }
  }

  void _startAttack(double damage, double w, double h, FighterState state) {
    isAttacking = true;
    attackDamage = damage;
    attackHasHit = false;
    current = state;
    animationTicker?.reset();
    
    if (w > 0 && h > 0) {
      final rectX = facingRight ? size.x : -w;
      final rectY = size.y / 2; 
      attackRect = Rect.fromLTWH(rectX, rectY, w, h);
    } else {
      attackRect = null;
    }
  }

  void takeDamage(double amount) {
    health -= amount;
    current = FighterState.hurt;
    animationTicker?.reset();
    
    // Knockback
    velocity.y = -300;
    isGrounded = false;
    velocity.x = facingRight ? -300 : 300;
    
    isAttacking = false;
    attackRect = null;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Animation completion checks
    if ((current == FighterState.attack || current == FighterState.kick) && (animationTicker?.done() ?? false)) {
      isAttacking = false;
      attackRect = null;
      current = FighterState.idle;
    }
    
    if (current == FighterState.hurt && (animationTicker?.done() ?? false)) {
      current = FighterState.idle;
    }

    if (isDashing) {
      dashTimer -= dt;
      if (dashTimer <= 0) isDashing = false;
    } else if (current != FighterState.hurt && !isAttacking) {
      if (leftPressed && !rightPressed) {
        velocity.x = -moveSpeed;
        if (isGrounded && !crouchPressed) current = FighterState.run;
      } else if (rightPressed && !leftPressed) {
        velocity.x = moveSpeed;
        if (isGrounded && !crouchPressed) current = FighterState.run;
      } else {
        velocity.x = 0;
      }
    }

    if (!isGrounded) {
      velocity.y += gravity * dt;
      if (current != FighterState.hurt && !isAttacking) {
        current = FighterState.jump;
      }
    }

    // Return to idle / crouch
    if (velocity.x == 0 && velocity.y == 0 && isGrounded && !isAttacking && current != FighterState.hurt) {
      if (crouchPressed) {
        current = FighterState.crouch;
      } else {
        current = FighterState.idle;
      }
    }

    // Handle Crouch visually
    if (current == FighterState.crouch) {
      scale.y = 0.6;
    } else {
      scale.y = 1.0;
    }

    position.x += velocity.x * dt;
    position.y += velocity.y * dt;

    final groundY = gameRef.size.y - GroundComponent.groundHeight;
    if (position.y >= groundY) {
      position.y = groundY;
      velocity.y = 0;
      isGrounded = true;
    } else {
      isGrounded = false;
    }

    final actualWidth = size.x / 2;
    if (position.x - actualWidth < 0) {
      position.x = actualWidth;
    } else if (position.x + actualWidth > gameRef.size.x) {
      position.x = gameRef.size.x - actualWidth;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Optional: Draw hitbox for debugging
    if (isAttacking && attackRect != null) {
      canvas.drawRect(attackRect!, _hitboxPaint);
    }
  }
}
