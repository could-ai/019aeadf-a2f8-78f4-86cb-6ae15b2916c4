import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Game Configuration
  static const double _playerSize = 40.0;
  static const double _enemySize = 40.0;
  static const double _safeZoneSize = 60.0;
  static const int _gameDurationSeconds = 15;
  static const double _foxSpeed = 3.0;
  static const double _chickenSpeed = 6.0;

  // Game State
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isWin = false;
  int _score = 0;
  int _timeLeft = _gameDurationSeconds;
  String _message = "Tap 'Start Game' to begin!";

  // Positions (normalized 0.0 to 1.0 relative to screen size, converted during render)
  // Using absolute coordinates for simplicity in logic
  Offset _chickenPos = const Offset(100, 100);
  Offset _foxPos = const Offset(300, 300);
  Offset _safeZonePos = const Offset(200, 500);
  Offset? _targetPos; // Where the chicken is moving to

  Timer? _gameLoopTimer;
  Timer? _countdownTimer;
  Size _screenSize = Size.zero;

  @override
  void dispose() {
    _stopGame();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _isWin = false;
      _timeLeft = _gameDurationSeconds;
      _message = "";
      _targetPos = null;
      
      // Randomize positions
      _randomizePositions();
    });

    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updateGame();
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _gameOver(false); // Time run out
      }
    });
  }

  void _randomizePositions() {
    if (_screenSize == Size.zero) return;
    
    final random = Random();
    double w = _screenSize.width;
    double h = _screenSize.height;
    double padding = 50.0;

    // Safe zone usually far from start
    _safeZonePos = Offset(
      random.nextDouble() * (w - 2 * padding) + padding,
      random.nextDouble() * (h - 2 * padding) + padding,
    );

    // Chicken starts somewhere
    _chickenPos = Offset(
      random.nextDouble() * (w - 2 * padding) + padding,
      random.nextDouble() * (h - 2 * padding) + padding,
    );

    // Fox starts far enough from chicken
    do {
      _foxPos = Offset(
        random.nextDouble() * (w - 2 * padding) + padding,
        random.nextDouble() * (h - 2 * padding) + padding,
      );
    } while ((_foxPos - _chickenPos).distance < 200); // Ensure minimum distance
  }

  void _stopGame() {
    _gameLoopTimer?.cancel();
    _countdownTimer?.cancel();
  }

  void _gameOver(bool win) {
    _stopGame();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _isWin = win;
      if (win) {
        _score += 10 + _timeLeft; // Bonus for time left
        _message = "Safe! You earned points. Tap to play again.";
      } else {
        _message = _timeLeft == 0 
            ? "Time's up! The fox got you." 
            : "Caught by the Fox! Game Over.";
        // Reset score on loss? Or keep it arcade style? Let's keep it arcade style but maybe reset if they want.
        // For now, we keep score accumulating until app restart or explicit reset.
      }
    });
  }

  void _updateGame() {
    if (!_isPlaying) return;

    setState(() {
      // 1. Move Chicken towards target
      if (_targetPos != null) {
        Offset dir = _targetPos! - _chickenPos;
        if (dir.distance < _chickenSpeed) {
          _chickenPos = _targetPos!;
          _targetPos = null; // Reached target
        } else {
          Offset move = Offset(
            cos(dir.direction) * _chickenSpeed,
            sin(dir.direction) * _chickenSpeed,
          );
          _chickenPos += move;
        }
      }

      // 2. Move Fox towards Chicken
      Offset foxDir = _chickenPos - _foxPos;
      Offset foxMove = Offset(
        cos(foxDir.direction) * _foxSpeed,
        sin(foxDir.direction) * _foxSpeed,
      );
      _foxPos += foxMove;

      // 3. Check Collisions
      
      // Fox catches Chicken
      if ((_foxPos - _chickenPos).distance < (_playerSize / 2 + _enemySize / 2)) {
        _gameOver(false);
      }

      // Chicken reaches Safe Zone
      if ((_chickenPos - _safeZonePos).distance < (_playerSize / 2 + _safeZoneSize / 2)) {
        _gameOver(true);
      }
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (!_isPlaying) return;
    setState(() {
      _targetPos = details.localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Initialize screen size once
          if (_screenSize == Size.zero) {
            _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
            // Initial positions centered if not started
            if (!_isPlaying && !_isGameOver) {
               _chickenPos = Offset(_screenSize.width / 2, _screenSize.height / 2);
               _foxPos = Offset(_screenSize.width / 4, _screenSize.height / 4);
               _safeZonePos = Offset(_screenSize.width * 0.75, _screenSize.height * 0.75);
            }
          }

          return GestureDetector(
            onTapDown: _onTapDown,
            behavior: HitTestBehavior.opaque, // Catch taps everywhere
            child: Stack(
              children: [
                // Background (Grass)
                Container(color: Colors.green[200]),

                // Safe Zone (Coop)
                Positioned(
                  left: _safeZonePos.dx - _safeZoneSize / 2,
                  top: _safeZonePos.dy - _safeZoneSize / 2,
                  child: Container(
                    width: _safeZoneSize,
                    height: _safeZoneSize,
                    decoration: BoxDecoration(
                      color: Colors.brown[400],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.brown[800]!, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 1)
                      ]
                    ),
                    child: const Center(
                      child: Text(
                        "🏠",
                        style: TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                ),

                // Target Marker (Visual feedback for tap)
                if (_targetPos != null)
                  Positioned(
                    left: _targetPos!.dx - 10,
                    top: _targetPos!.dy - 10,
                    child: Opacity(
                      opacity: 0.5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),

                // Chicken (Player)
                Positioned(
                  left: _chickenPos.dx - _playerSize / 2,
                  top: _chickenPos.dy - _playerSize / 2,
                  child: Container(
                    width: _playerSize,
                    height: _playerSize,
                    alignment: Alignment.center,
                    child: const Text(
                      "🐔",
                      style: TextStyle(fontSize: 35),
                    ),
                  ),
                ),

                // Fox (Enemy)
                Positioned(
                  left: _foxPos.dx - _enemySize / 2,
                  top: _foxPos.dy - _enemySize / 2,
                  child: Container(
                    width: _enemySize,
                    height: _enemySize,
                    alignment: Alignment.center,
                    child: const Text(
                      "🦊",
                      style: TextStyle(fontSize: 35),
                    ),
                  ),
                ),

                // HUD (Heads Up Display)
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Score: $_score",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _timeLeft < 5 ? Colors.red.withOpacity(0.8) : Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Time: $_timeLeft",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // Game Over / Start Overlay
                if (!_isPlaying)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isGameOver 
                              ? (_isWin ? "YOU ESCAPED!" : "GAME OVER") 
                              : "FOX CHASE",
                            style: TextStyle(
                              color: _isWin ? Colors.greenAccent : Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              shadows: const [Shadow(blurRadius: 10, color: Colors.black)],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _isGameOver ? "Play Again" : "Start Game",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
