import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';

// -- Cached Paints for Zero-Allocation Rendering --
final Paint _groundPaint = Paint()..color = const Color(0xFF2C2C2C);
final Paint _healthBgPaint = Paint()..color = const Color(0xFF222222);
final Paint _healthFillPaint = Paint()..color = Colors.greenAccent;
final Paint _healthBorderPaint = Paint()
  ..color = Colors.white70
  ..style = PaintingStyle.stroke
  ..strokeWidth = 3.0;

final TextPaint _playerLabelPaint = TextPaint(
  style: const TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))],
  ),
);

enum FighterState { idle, run, jump, attack, kick, hurt, crouch, block }

class ShadowFightGame extends FlameGame {
  late final Fighter player1;
  late final Fighter player2;
  
  bool isGameOver = false;
  final void Function(int) onGameOver;
  String player1Name;
  String player2Name;

  ShadowFightGame({
    required this.onGameOver,
    this.player1Name = "PLAYER 1",
    this.player2Name = "PLAYER 2",
  });

  void updatePlayerNames(String p1, String p2) {
    player1Name = p1;
    player2Name = p2;
  }

  late final TextPainter p1WinText;
  late final TextPainter p2WinText;
  late final TextPainter drawText;

  @override
  Color backgroundColor() => const Color(0xFF1E1E1E);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Preload Audio
    await FlameAudio.audioCache.loadAll([
      'bgm.mp3',
      'sword.mp3',
      'throw.mp3',
      'hurt.mp3',
      'jump.mp3',
      'block.mp3',
      'dash.mp3',
    ]);
    
    // Start BGM
    FlameAudio.bgm.play('bgm.mp3');

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
      final winner = player1.health > player2.health ? 1 : 2;
      onGameOver(winner);
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
    
    player1.reset(Vector2(size.x * 0.2, size.y - 40));
    player2.reset(Vector2(size.x * 0.8, size.y - 40));
    
    children.whereType<Fireball>().forEach((f) => f.removeFromParent());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final p1Percentage = (player1.health / 100).clamp(0.0, 1.0);
    final p2Percentage = (player2.health / 100).clamp(0.0, 1.0);
    
    final p1Width = p1Percentage * 300;
    final p2Width = p2Percentage * 300;

    Color getHealthColor(double percentage) {
      if (percentage > 0.6) return Colors.greenAccent;
      if (percentage > 0.3) return Colors.orangeAccent;
      return Colors.redAccent;
    }

    // Player 1
    _playerLabelPaint.render(canvas, player1Name, Vector2(50, 15));
    final p1BgRect = RRect.fromLTRBR(50, 45, 350, 65, const Radius.circular(5.0));
    final p1FillRect = RRect.fromLTRBR(50, 45, 50 + p1Width, 65, const Radius.circular(5.0));
    
    canvas.drawRRect(p1BgRect, _healthBgPaint);
    _healthFillPaint.color = getHealthColor(p1Percentage);
    if (p1Width > 0) canvas.drawRRect(p1FillRect, _healthFillPaint);
    canvas.drawRRect(p1BgRect, _healthBorderPaint);

    // Player 2
    _playerLabelPaint.render(canvas, player2Name, Vector2(size.x - 50, 15), anchor: Anchor.topRight);
    final p2BgRect = RRect.fromLTRBR(size.x - 350, 45, size.x - 50, 65, const Radius.circular(5.0));
    final p2FillRect = RRect.fromLTRBR(size.x - 50 - p2Width, 45, size.x - 50, 65, const Radius.circular(5.0));
    
    canvas.drawRRect(p2BgRect, _healthBgPaint);
    _healthFillPaint.color = getHealthColor(p2Percentage);
    if (p2Width > 0) canvas.drawRRect(p2FillRect, _healthFillPaint);
    canvas.drawRRect(p2BgRect, _healthBorderPaint);

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

class Fireball extends SpriteComponent with HasGameRef<ShadowFightGame> {
  final int ownerId;
  final bool movingRight;
  final double speed = 800.0;
  final double damage = 20.0;

  Fireball({
    required this.ownerId,
    required this.movingRight,
    required Vector2 startPosition,
  }) : super(position: startPosition, size: Vector2(80, 40));

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = await gameRef.loadSprite('fireball.png');
    if (!movingRight) {
      flipHorizontallyAroundCenter();
    }
  }

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
}

class Fighter extends SpriteAnimationGroupComponent<FighterState> with HasGameRef<ShadowFightGame> {
  final int playerId;
  bool facingRight;
  
  double health = 100;
  
  static const double moveSpeed = 550.0;
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
         anchor: Anchor.bottomCenter, // Sets logical position to be the feet
       );

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final dynamicHeight = gameRef.size.y * 0.45;
    size = Vector2(dynamicHeight * (150 / 225), dynamicHeight);

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
    final blockFrames = List.generate(5, (i) => 'ninja/_${i + 14}.png');

    final idleAnim = await loadAnimation(idleFrames);
    final runAnim = await loadAnimation(runFrames);
    final jumpAnim = await loadAnimation(jumpFrames);
    final attackAnim = await loadAnimation(attackFrames, loop: false);
    final kickAnim = await loadAnimation(kickFrames, loop: false);
    final hurtAnim = await loadAnimation(hurtFrames, loop: false);
    final blockAnim = await loadAnimation(blockFrames, loop: true);

    animations = {
      FighterState.idle: idleAnim,
      FighterState.run: runAnim,
      FighterState.jump: jumpAnim,
      FighterState.attack: attackAnim,
      FighterState.kick: kickAnim,
      FighterState.hurt: hurtAnim,
      FighterState.crouch: idleAnim, // fallback
      FighterState.block: blockAnim,
    };

    current = FighterState.idle;
  }

  void reset(Vector2 initialPosition) {
    current = FighterState.idle;
    health = 100;
    position.setFrom(initialPosition);
    velocity.setZero();
    leftPressed = false;
    rightPressed = false;
    crouchPressed = false;
    isAttacking = false;
    attackHasHit = false;
    isDashing = false;
    dashTimer = 0;
    scale.y = 1.0;
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
    final bool isBlocking = current == FighterState.block;
    
    switch (action) {
      case 'block': 
        if (isPressed) {
          if (current != FighterState.block) FlameAudio.play('block.mp3');
          current = FighterState.block;
        } else if (current == FighterState.block) {
          current = FighterState.idle;
        }
        break;
      case 'left': leftPressed = isPressed; break;
      case 'right': rightPressed = isPressed; break;
      case 'down': crouchPressed = isPressed; break;
      case 'up':
        if (isPressed && isGrounded && !isAttacking && !isBlocking) {
          FlameAudio.play('jump.mp3');
          velocity.y = jumpForce;
          isGrounded = false;
          current = FighterState.jump;
        }
        break;
      case 'punch':
        if (isPressed && !isAttacking && isGrounded && !isBlocking) _startAttack(10, 40, 20, FighterState.attack);
        break;
      case 'kick':
        if (isPressed && !isAttacking && isGrounded && !isBlocking) _startAttack(15, 50, 20, FighterState.kick);
        break;
      case 'fireball':
        if (isPressed && !isAttacking && isGrounded && !isBlocking) {
          _startAttack(0, 0, 0, FighterState.attack); 
          gameRef.spawnFireball(this);
        }
        break;
      case 'dash':
        if (isPressed && !isDashing && isGrounded && !isAttacking && !isBlocking) {
          FlameAudio.play('dash.mp3');
          isDashing = true;
          dashTimer = 0.2;
          velocity.x = facingRight ? 1500 : -1500;
          current = FighterState.run;
        }
        break;
      case 'heal':
        if (isPressed && isGrounded && !isAttacking && !isBlocking) {
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
    
    if (state == FighterState.attack) {
      FlameAudio.play('sword.mp3');
    } else if (state == FighterState.kick) {
      FlameAudio.play('throw.mp3');
    }
    
    if (w > 0 && h > 0) {
      final rectX = facingRight ? size.x : -w;
      final rectY = size.y / 2; 
      attackRect = Rect.fromLTWH(rectX, rectY, w, h);
    } else {
      attackRect = null;
    }
  }

  void takeDamage(double amount) {
    final bool isBlocking = current == FighterState.block;
    if (isBlocking) {
      amount *= 0.2; // 80% damage reduction
    }
    
    health -= amount;
    
    if (!isBlocking) {
      FlameAudio.play('hurt.mp3');
      current = FighterState.hurt;
      animationTicker?.reset();
      
      // Knockback
      velocity.y = -300;
      isGrounded = false;
      velocity.x = facingRight ? -300 : 300;
      
      isAttacking = false;
      attackRect = null;
    }
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
      if (current == FighterState.block) {
        velocity.x = 0;
      } else if (leftPressed && !rightPressed) {
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
    if (velocity.x == 0 && velocity.y == 0 && isGrounded && !isAttacking && current != FighterState.hurt && current != FighterState.block) {
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
  }
}
