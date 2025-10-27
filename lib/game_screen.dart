import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flame/components.dart';

// Block class
enum BlockType {
  normal,
  lineClear,
  colorBomb,
  timeSlow,
  shrink,
}

class Block {
  List<List<int>> shape;
  Offset position;
  bool isDragging;
  Color color;
  double scale;
  double rotation;
  double opacity;
  BlockType type;
  bool isShrunken;

  Block(
    this.shape,
    this.position, {
    this.isDragging = false,
    Color? color,
    this.scale = 0.0,
    this.rotation = 0.0,
    this.opacity = 0.0,
    this.type = BlockType.normal,
    this.isShrunken = false,
  }) : color =
           color ??
           BlockBlastGame.blockColors[Random().nextInt(
             BlockBlastGame.blockColors.length,
           )] {
    if (Random().nextDouble() < 0.15) {
      type = BlockType.values[Random().nextInt(BlockType.values.length)];
      switch (type) {
        case BlockType.lineClear:
          color = Colors.yellow[700]!;
          break;
        case BlockType.colorBomb:
          color = Colors.purple[400]!;
          break;
        case BlockType.timeSlow:
          color = Colors.blue[300]!;
          break;
        case BlockType.shrink:
          color = Colors.green[300]!;
          isShrunken = true;
          break;
        default:
          break;
      }
    }
    _startEntryAnimation();
  }

  void _startEntryAnimation() {
    Future.delayed(Duration.zero, () async {
      for (int i = 0; i < 20; i++) {
        scale = sin(i / 20 * pi) * 0.3 + 0.7;
        rotation = sin(i / 10 * pi) * 0.1;
        opacity = min(1.0, i / 10);
        await Future.delayed(const Duration(milliseconds: 16));
      }
      scale = 1.0;
      rotation = 0.0;
      opacity = 1.0;
    });
  }
}

class BlockBlastGame extends FlameGame with PanDetector {
  static const int gridSize = 10;
  late double cellSize;
  late double cellPadding;
  late double gridPadding;
  late double bottomBlocksY;

  // Audio management
  bool audioLoaded = false;
  
  // Hint System
  bool showHint = false;
  (int, int, int)? hintPosition;
  double hintOpacity = 0.0;
  bool isHintAvailable = false;
  int hintCost = 0;
  
  // Responsive scaling factors
  double get scaleFactor => min(size.x, size.y) / 600;
  double get smallScaleFactor => min(1.0, scaleFactor);

  // AI Analysis
  String aiFeedback = "";
  bool showFeedback = false;
  double feedbackOpacity = 0.0;
  Color feedbackColor = Colors.white;

  // Game state
  int highScore = 0;
  int maxCombo = 0;
  int totalLinesCleared = 0;
  int specialPatternsFound = 0;
  int currentCombo = 0;
  double comboTimer = 0.0;
  static const double comboTimeWindow = 3.0;

  // Power-up effects
  bool isTimeSlowed = false;
  double timeSlowDuration = 0.0;
  static const double timeSlowFactor = 0.5;

  // Pattern recognition
  bool hasRainbowPattern = false;
  bool hasFramePattern = false;
  bool hasDiagonalLine = false;

  // Properties for placement preview
  (int, int)? currentGridPosition;
  double previewOpacity = 0.0;
  bool isValidPosition = false;

  bool showContinuePrompt = false;
  double continuePromptTimer = 5.0;
  bool canContinue = true;
  int continueCost = 0;

  // Animation properties
  List<({Offset position, Color color, double scale, double opacity})>
  blockPlacementEffects = [];
  List<({int row, int col, double scale, double opacity})> cellClearEffects = [];
  double scoreAnimationScale = 1.0;
  Color? lastScoreColor;
  int displayScore = 0;

  // Modern color palette for blocks
  static final List<Color> blockColors = [
    const Color(0xFF2196F3),
    const Color(0xFFE91E63),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
    const Color(0xFFFFEB3B),
    const Color(0xFF673AB7),
  ];

  // Gradient pairs for each block color
  static final Map<Color, List<Color>> blockGradients = {
    blockColors[0]: [const Color(0xFF2196F3), const Color(0xFF1976D2)],
    blockColors[1]: [const Color(0xFFE91E63), const Color(0xFFC2185B)],
    blockColors[2]: [const Color(0xFF4CAF50), const Color(0xFF388E3C)],
    blockColors[3]: [const Color(0xFFFF9800), const Color(0xFFF57C00)],
    blockColors[4]: [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
    blockColors[5]: [const Color(0xFF00BCD4), const Color(0xFF0097A7)],
    blockColors[6]: [const Color(0xFFFFEB3B), const Color(0xFFFBC02D)],
    blockColors[7]: [const Color(0xFF673AB7), const Color(0xFF512DA8)],
  };

  List<List<Color?>> grid = List.generate(
    gridSize,
    (_) => List.filled(gridSize, null),
  );
  int score = 0;
  Random random = Random();

  List<Block> bottomBlocks = [];
  Block? draggingBlock;
  int placedBlockCount = 0;

  // Score multiplier for consecutive successful placements
  double scoreMultiplier = 1.0;
  int consecutivePlacements = 0;
  DateTime? lastPlacementTime;
  bool hasExplosivePowerUp = false;
  bool hasColorMatchPowerUp = false;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _calculateResponsiveValues();
    generateBottomBlocks();
    await _loadAudio();
    _updateHintAvailability();
  }

  Future<void> _loadAudio() async {
    try {
      await FlameAudio.audioCache.loadAll(['error.mp3', 'good.mp3']);
      audioLoaded = true;
    } catch (e) {
      print('Error loading audio: $e');
    }
  }

  void _playErrorSound() {
    if (audioLoaded) {
      try {
        FlameAudio.play('error.mp3', volume: 0.7);
      } catch (e) {
        print('Error playing sound: $e');
      }
    }
  }

  void _playGoodSound() {
    if (audioLoaded) {
      try {
        FlameAudio.play('good.mp3', volume: 0.7);
      } catch (e) {
        print('Error playing sound: $e');
      }
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _calculateResponsiveValues();
    if (bottomBlocks.isNotEmpty) {
      _positionBottomBlocks();
    }
  }

  void _calculateResponsiveValues() {
    final minDimension = min(size.x, size.y);
    
    cellSize = max(30.0, min(50.0, minDimension * 0.08));
    cellPadding = max(2.0, cellSize * 0.08);
    gridPadding = max(20.0, minDimension * 0.05);
    
    final gridHeight = gridSize * cellSize + (gridSize - 1) * cellPadding;
    bottomBlocksY = gridPadding + gridHeight + 40;
  }

  void generateBottomBlocks() {
    bottomBlocks = List.generate(3, (_) => Block(randomShape(), Offset(0, 0)));
    _positionBottomBlocks();
    placedBlockCount = 0;
    _updateHintAvailability();
  }

  void _positionBottomBlocks() {
    double totalWidth = 0;
    for (var block in bottomBlocks) {
      totalWidth += block.shape[0].length * (cellSize + cellPadding);
    }
    totalWidth += (bottomBlocks.length - 1) * cellSize;

    double startX = (size.x - totalWidth) / 2;
    for (int i = 0; i < bottomBlocks.length; i++) {
      double blockWidth = bottomBlocks[i].shape[0].length * (cellSize + cellPadding);
      bottomBlocks[i].position = Offset(startX, bottomBlocksY);
      startX += blockWidth + cellSize;
    }
  }

  // Hint System Functions
  void _updateHintAvailability() {
    hintCost = score ~/ 2;
    isHintAvailable = score > 0 && hintCost > 0;
  }

  void activateHint() {
    if (!isHintAvailable || score == 0) return;
    
    hintCost = score ~/ 2;
    if (hintCost <= 0) return;
    
    score -= hintCost;
    displayScore = score;
    
    _findAndShowBestMove();
    _updateHintAvailability();
    
    aiFeedback = "Hint: -$hintCost points";
    feedbackColor = Colors.orange;
    showFeedback = true;
    feedbackOpacity = 1.0;
    
    Future.delayed(const Duration(seconds: 2), () {
      showFeedback = false;
    });
  }

  void _findAndShowBestMove() {
    int bestScore = -1;
    (int, int, int)? bestMove;
    
    for (int blockIndex = 0; blockIndex < bottomBlocks.length; blockIndex++) {
      var block = bottomBlocks[blockIndex];
      
      for (int y = 0; y <= gridSize - block.shape.length; y++) {
        for (int x = 0; x <= gridSize - block.shape[0].length; x++) {
          if (canPlace(block.shape, x, y)) {
            int placementScore = _calculatePlacementScore(block, x, y);
            if (placementScore > bestScore) {
              bestScore = placementScore;
              bestMove = (blockIndex, x, y);
            }
          }
        }
      }
    }
    
    if (bestMove != null) {
      hintPosition = bestMove;
      showHint = true;
      hintOpacity = 1.0;
      
      Future.delayed(const Duration(seconds: 5), () {
        showHint = false;
        hintPosition = null;
      });
    }
  }

  void _drawHint(Canvas canvas) {
    if (!showHint || hintPosition == null) return;
    
    final (blockIndex, hintX, hintY) = hintPosition!;
    if (blockIndex >= bottomBlocks.length) return;
    
    var block = bottomBlocks[blockIndex];
    final gridWidth = gridSize * cellSize + (gridSize - 1) * cellPadding;
    final gridLeft = (size.x - gridWidth) / 2;
    final gridTop = gridPadding;
    
    final blockRect = Rect.fromLTWH(
      block.position.dx,
      block.position.dy,
      block.shape[0].length * cellSize,
      block.shape.length * cellSize,
    );
    
    final glowAnimation = sin(DateTime.now().millisecondsSinceEpoch / 200) * 0.3 + 0.7;
    final glowPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.5 * hintOpacity * glowAnimation)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(blockRect.inflate(8), Radius.circular(cellSize * 0.2)),
      glowPaint,
    );
    
    for (int y = 0; y < block.shape.length; y++) {
      for (int x = 0; x < block.shape[y].length; x++) {
        if (block.shape[y][x] == 1) {
          final hintRect = Rect.fromLTWH(
            gridLeft + (hintX + x) * (cellSize + cellPadding),
            gridTop + (hintY + y) * (cellSize + cellPadding),
            cellSize,
            cellSize,
          );
          
          final placementGlow = Paint()
            ..color = Colors.green.withOpacity(0.4 * hintOpacity * glowAnimation)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
          
          canvas.drawRRect(
            RRect.fromRectAndRadius(hintRect.inflate(6), Radius.circular(cellSize * 0.2)),
            placementGlow,
          );
          
          canvas.drawRRect(
            RRect.fromRectAndRadius(hintRect, Radius.circular(cellSize * 0.16)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.green.withOpacity(hintOpacity),
          );
        }
      }
    }
    
    final blockCenter = Offset(
      blockRect.center.dx,
      blockRect.center.dy,
    );
    
    final placementCenter = Offset(
      gridLeft + (hintX + block.shape[0].length / 2) * (cellSize + cellPadding),
      gridTop + (hintY + block.shape.length / 2) * (cellSize + cellPadding),
    );
    
    final linePaint = Paint()
      ..color = Colors.yellow.withOpacity(0.6 * hintOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(blockCenter, placementCenter, linePaint);
    _drawArrow(canvas, placementCenter, blockCenter, Colors.yellow.withOpacity(hintOpacity));
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final direction = (to - from).normalized;
    const arrowSize = 8.0;
    
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(from.dx, from.dy);
    
    final perpendicular = Offset(-direction.dy, direction.dx);
    final arrowPoint1 = from + direction * arrowSize + perpendicular * arrowSize * 0.5;
    final arrowPoint2 = from + direction * arrowSize - perpendicular * arrowSize * 0.5;
    
    path.lineTo(arrowPoint1.dx, arrowPoint1.dy);
    path.lineTo(arrowPoint2.dx, arrowPoint2.dy);
    path.close();
    
    canvas.drawPath(path, arrowPaint);
  }

  // AI Analysis
  void _analyzeMove(Block block, int x, int y) {
    int placementScore = _calculatePlacementScore(block, x, y);
    
    if (placementScore >= 40) {
      aiFeedback = "Great Move! +${placementScore}";
      feedbackColor = Colors.green;
    } else if (placementScore >= 25) {
      aiFeedback = "Good Move +${placementScore}";
      feedbackColor = Colors.lightGreen;
    } else if (placementScore >= 15) {
      aiFeedback = "Nice +${placementScore}";
      feedbackColor = Colors.yellow;
    } else if (placementScore >= 5) {
      aiFeedback = "OK +${placementScore}";
      feedbackColor = Colors.orange;
    } else {
      aiFeedback = "Poor +${placementScore}";
      feedbackColor = Colors.red;
    }
    
    showFeedback = true;
    feedbackOpacity = 1.0;
    
    Future.delayed(const Duration(seconds: 2), () {
      showFeedback = false;
    });
  }

  int _calculatePlacementScore(Block block, int x, int y) {
    int score = 0;
    
    var tempGrid = _copyGrid();
    _placeBlockOnGrid(tempGrid, block, x, y);
    
    score += _checkLinesForScore(tempGrid) * 15;
    
    int centerX = gridSize ~/ 2;
    int centerY = gridSize ~/ 2;
    double distanceFromCenter = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2));
    score += max(0, (12 - distanceFromCenter).toInt());
    
    score += block.shape.length * block.shape[0].length;
    
    return score;
  }

  List<List<Color?>> _copyGrid() {
    return grid.map((row) => List<Color?>.from(row)).toList();
  }

  void _placeBlockOnGrid(List<List<Color?>> targetGrid, Block block, int x, int y) {
    for (int dy = 0; dy < block.shape.length; dy++) {
      for (int dx = 0; dx < block.shape[dy].length; dx++) {
        if (block.shape[dy][dx] == 1) {
          targetGrid[y + dy][x + dx] = block.color;
        }
      }
    }
  }

  int _checkLinesForScore(List<List<Color?>> targetGrid) {
    int lines = 0;
    
    for (int y = 0; y < gridSize; y++) {
      if (targetGrid[y].every((cell) => cell != null)) {
        lines++;
      }
    }
    
    for (int x = 0; x < gridSize; x++) {
      bool fullColumn = true;
      for (int y = 0; y < gridSize; y++) {
        if (targetGrid[y][x] == null) {
          fullColumn = false;
          break;
        }
      }
      if (fullColumn) lines++;
    }
    
    return lines;
  }

  List<List<int>> randomShape() {
    int type = random.nextInt(20);
    switch (type) {
      case 0: return [[1]];
      case 1: return [[1, 1]];
      case 2: return [[1], [1]];
      case 3: return [[1, 1], [1, 1]];
      case 4: return [[1, 1, 1]];
      case 5: return [[1, 0], [1, 0], [1, 1]];
      case 6: return [[0, 1], [0, 1], [1, 1]];
      case 7: return [[1, 1, 1], [0, 1, 0]];
      case 8: return [[0, 1, 1], [1, 1, 0]];
      case 9: return [[1, 1, 0], [0, 1, 1]];
      case 10: return [[1], [1], [1], [1]];
      case 11: return [[0, 1, 0], [1, 1, 1], [0, 1, 0]];
      case 12: return [[1, 1, 1], [1, 1, 1], [1, 1, 1]];
      case 13: return [[1, 0, 1], [1, 0, 1], [1, 1, 1]];
      case 14: return [[1, 0, 1], [1, 1, 1], [1, 0, 1]];
      case 15: return [[1, 0, 1], [0, 1, 0], [1, 0, 1]];
      case 16: return [[1, 1, 1], [1, 0, 1], [1, 1, 1]];
      case 17: return [[1, 1, 1], [1, 0, 0], [1, 1, 1]];
      case 18: return [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
      case 19: return [[1, 1, 0], [1, 0, 0], [1, 1, 1]];
      default: return [[1]];
    }
  }

  bool canPlaceAnyBlock() {
    for (var block in bottomBlocks) {
      for (int y = 0; y <= gridSize - block.shape.length; y++) {
        for (int x = 0; x <= gridSize - block.shape[0].length; x++) {
          if (canPlace(block.shape, x, y)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update block placement effects
    for (int i = blockPlacementEffects.length - 1; i >= 0; i--) {
      var effect = blockPlacementEffects[i];
      effect = (
        position: effect.position,
        color: effect.color,
        scale: effect.scale - dt * 2,
        opacity: effect.opacity - dt * 2,
      );
      if (effect.opacity <= 0) {
        blockPlacementEffects.removeAt(i);
      } else {
        blockPlacementEffects[i] = effect;
      }
    }

    // Update cell clear effects
    final now = DateTime.now().millisecondsSinceEpoch / 300.0;
    for (int i = cellClearEffects.length - 1; i >= 0; i--) {
      var effect = cellClearEffects[i];
      double waveOffset = sin(now + effect.col * 0.5) * 4.0;
      effect = (
        row: (effect.row + waveOffset * 0.1).round(),
        col: effect.col,
        scale: effect.scale + dt * 2 + sin(now * 4) * 0.1,
        opacity: effect.opacity - dt * 1.5,
      );
      if (effect.opacity <= 0) {
        cellClearEffects.removeAt(i);
      } else {
        cellClearEffects[i] = effect;
        if (Random().nextDouble() < dt * 2) {
          final sparkX = effect.col + (Random().nextDouble() - 0.5) * 0.5;
          final sparkY = effect.row + (Random().nextDouble() - 0.5) * 0.5;
          cellClearEffects.add((
            row: sparkY.round(),
            col: sparkX.round(),
            scale: 0.2,
            opacity: 1.0,
          ));
        }
      }
    }

    // Update hint opacity
    if (showHint) {
      hintOpacity = max(0.0, hintOpacity - dt * 0.2);
      if (hintOpacity <= 0) {
        showHint = false;
        hintPosition = null;
      }
    }

    // Update feedback opacity
    if (showFeedback) {
      feedbackOpacity = max(0.0, feedbackOpacity - dt * 0.5);
      if (feedbackOpacity <= 0) {
        showFeedback = false;
      }
    }

    // Animate score
    if (scoreAnimationScale > 1.0) {
      scoreAnimationScale = max(1.0, scoreAnimationScale - dt * 2);
    }
    if (displayScore < score) {
      displayScore = min(score, displayScore + (score - displayScore) ~/ 10 + 1);
    }

    if (showContinuePrompt) {
      continuePromptTimer -= dt;
      if (continuePromptTimer <= 0) {
        if (score % 2 == 0) {
          startNewGame();
        } else {
          bottomBlocks.clear();
          showContinuePrompt = false;
          continuePromptTimer = 5.0;
        }
      }
    }

    if (bottomBlocks.isEmpty && !showContinuePrompt) {
      Future.delayed(const Duration(seconds: 2), () {
        startNewGame();
      });
    }

    if (!showContinuePrompt && bottomBlocks.isNotEmpty && !canPlaceAnyBlock()) {
      showContinuePrompt = true;
      continuePromptTimer = 5.0;
      canContinue = true;
      continueCost = score ~/ 2;
      _playErrorSound();
    }

    for (var block in bottomBlocks) {
      if (block.scale < 1.0) {
        block.scale = min(1.0, block.scale + dt * 5);
      }
      if (block.opacity < 1.0) {
        block.opacity = min(1.0, block.opacity + dt * 5);
      }
    }
    
    _updateHintAvailability();
  }

  void continueGame() {
    if (score % 2 == 0) {
      score = continueCost;
      displayScore = continueCost;
      showContinuePrompt = false;
      continuePromptTimer = 5.0;
      generateBottomBlocks();
      _updateHintAvailability();
    }
  }

  void startNewGame() {
    score = 0;
    displayScore = 0;
    showContinuePrompt = false;
    continuePromptTimer = 5.0;
    scoreMultiplier = 1.0;
    consecutivePlacements = 0;
    hasExplosivePowerUp = false;
    hasColorMatchPowerUp = false;
    grid = List.generate(gridSize, (_) => List.filled(gridSize, null));
    generateBottomBlocks();
    _updateHintAvailability();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw animated background gradient
    final bgRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF1A237E),
          const Color(0xFF0D47A1),
          const Color(0xFF1A237E),
        ],
        stops: [0.0, (sin(now) + 1) / 2, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Add subtle pattern overlay
    final patternSize = max(15.0, 20 * smallScaleFactor);
    for (int i = 0; i < size.x; i += patternSize.toInt()) {
      for (int j = 0; j < size.y; j += patternSize.toInt()) {
        canvas.drawCircle(
          Offset(i.toDouble(), j.toDouble()),
          1,
          Paint()..color = Colors.white.withOpacity(0.03),
        );
      }
    }

    // Calculate grid position to center it
    final gridWidth = gridSize * cellSize + (gridSize - 1) * cellPadding;
    final gridHeight = gridSize * cellSize + (gridSize - 1) * cellPadding;
    final gridLeft = (size.x - gridWidth) / 2;
    final gridTop = gridPadding;

    // Draw grid background with gradient
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final cellRect = Rect.fromLTWH(
          gridLeft + x * (cellSize + cellPadding),
          gridTop + y * (cellSize + cellPadding),
          cellSize,
          cellSize,
        );

        final cellPaint = Paint()..color = Colors.white.withOpacity(0.05);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            cellRect.inflate(1),
            Radius.circular(cellSize * 0.2),
          ),
          Paint()
            ..color = Colors.white.withOpacity(0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2),
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect, Radius.circular(cellSize * 0.16)),
          cellPaint,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cellRect.left + 1,
              cellRect.top + 1,
              cellRect.width - 2,
              cellRect.height - 2,
            ),
            Radius.circular(cellSize * 0.14),
          ),
          Paint()..color = Colors.white.withOpacity(0.05),
        );

        // Draw placed blocks
        if (grid[y][x] != null) {
          final blockPaint = Paint()
            ..color = grid[y][x]!
            ..style = PaintingStyle.fill;

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              cellRect.translate(2, 2),
              Radius.circular(cellSize * 0.16),
            ),
            Paint()..color = Colors.black.withOpacity(0.3),
          );

          canvas.drawRRect(
            RRect.fromRectAndRadius(cellRect, Radius.circular(cellSize * 0.16)),
            blockPaint,
          );

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                cellRect.left + 2,
                cellRect.top + 2,
                cellRect.width - 4,
                cellRect.height - 4,
              ),
              Radius.circular(cellSize * 0.12),
            ),
            Paint()..color = Colors.white.withOpacity(0.2),
          );
        }
      }
    }

    // Draw preview when dragging
    if (draggingBlock != null && currentGridPosition != null) {
      final (previewX, previewY) = currentGridPosition!;
      final gridWidth = gridSize * cellSize + (gridSize - 1) * cellPadding;
      final gridLeft = (size.x - gridWidth) / 2;
      final gridHeight = gridSize * cellSize + (gridSize - 1) * cellPadding;
      final gridTop = gridPadding;

      for (int y = 0; y < draggingBlock!.shape.length; y++) {
        for (int x = 0; x < draggingBlock!.shape[y].length; x++) {
          if (draggingBlock!.shape[y][x] == 1) {
            final previewRect = Rect.fromLTWH(
              gridLeft + (previewX + x) * (cellSize + cellPadding),
              gridTop + (previewY + y) * (cellSize + cellPadding),
              cellSize,
              cellSize,
            );

            final glowPaint = Paint()
              ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8)
              ..color = isValidPosition
                  ? draggingBlock!.color.withOpacity(previewOpacity * 0.5)
                  : Colors.red.withOpacity(previewOpacity * 0.5);

            canvas.drawRRect(
              RRect.fromRectAndRadius(previewRect, Radius.circular(cellSize * 0.16)),
              Paint()
                ..color = isValidPosition
                    ? draggingBlock!.color.withOpacity(previewOpacity * 0.3)
                    : Colors.red.withOpacity(previewOpacity * 0.3),
            );

            canvas.drawRRect(
              RRect.fromRectAndRadius(
                previewRect.inflate(4),
                Radius.circular(cellSize * 0.2),
              ),
              glowPaint,
            );

            canvas.drawRRect(
              RRect.fromRectAndRadius(previewRect, Radius.circular(cellSize * 0.16)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = isValidPosition
                    ? draggingBlock!.color.withOpacity(previewOpacity)
                    : Colors.red.withOpacity(previewOpacity),
            );
          }
        }
      }
    }

    // Draw hint if active
    if (showHint) {
      _drawHint(canvas);
    }

    // Draw bottom blocks with effects
    for (var block in bottomBlocks) {
      for (int y = 0; y < block.shape.length; y++) {
        for (int x = 0; x < block.shape[y].length; x++) {
          if (block.shape[y][x] == 1) {
            final blockRect = Rect.fromLTWH(
              block.position.dx + x * cellSize,
              block.position.dy + y * cellSize,
              cellSize - 2,
              cellSize - 2,
            );

            canvas.drawRRect(
              RRect.fromRectAndRadius(
                blockRect.inflate(2),
                Radius.circular(cellSize * 0.2),
              ),
              Paint()
                ..color = block.color.withOpacity(0.3)
                ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3),
            );

            final gradientColors =
                blockGradients[block.color] ?? [block.color, block.color];
            final blockPaint = Paint()
              ..shader = LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(blockRect);

            canvas.drawRRect(
              RRect.fromRectAndRadius(blockRect, Radius.circular(cellSize * 0.16)),
              blockPaint,
            );

            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  blockRect.left + 2,
                  blockRect.top + 2,
                  blockRect.width - 4,
                  blockRect.height - 4,
                ),
                Radius.circular(cellSize * 0.12),
              ),
              Paint()..color = Colors.white.withOpacity(0.3),
            );
          }
        }
      }
    }

    // Draw AI feedback if active
    if (showFeedback && aiFeedback.isNotEmpty) {
      _drawAiFeedback(canvas);
    }

    // Responsive UI elements
    final baseFontSize = 16.0 * scaleFactor;
    final panelHeight = 40.0 * smallScaleFactor;
    final panelWidth = 160.0 * smallScaleFactor;

    // Draw score panel background
    final scorePanelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, panelHeight / 2 + 10),
        width: panelWidth,
        height: panelHeight,
      ),
      Radius.circular(panelHeight / 2),
    );

    canvas.drawRRect(
      scorePanelRect.inflate(2),
      Paint()
        ..color = Colors.blue[400]!.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4),
    );

    canvas.drawRRect(
      scorePanelRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.blue[900]!.withOpacity(0.7),
            Colors.blue[700]!.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(scorePanelRect.outerRect),
    );

    // Draw hint button
    final hintButtonSize = 50.0 * smallScaleFactor;
    final hintButtonRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(hintButtonSize / 2 + 10, panelHeight / 2 + 10),
        width: hintButtonSize,
        height: hintButtonSize,
      ),
      Radius.circular(hintButtonSize / 2),
    );

    final hintButtonGlowColor = isHintAvailable 
        ? Colors.orange[400]!.withOpacity(0.3)
        : Colors.grey[400]!.withOpacity(0.2);

    canvas.drawRRect(
      hintButtonRect.inflate(2),
      Paint()
        ..color = hintButtonGlowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4),
    );

    final hintButtonGradient = isHintAvailable
        ? LinearGradient(
            colors: [
              Colors.orange[700]!.withOpacity(0.9),
              Colors.orange[500]!.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Colors.grey[700]!.withOpacity(0.5),
              Colors.grey[500]!.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    canvas.drawRRect(
      hintButtonRect,
      Paint()
        ..shader = hintButtonGradient.createShader(hintButtonRect.outerRect),
    );

    _drawLampIcon(canvas, hintButtonRect.center, isHintAvailable);

    if (isHintAvailable && hintCost > 0) {
      final costText = '-$hintCost';
      final costPainter = TextPainter(
        text: TextSpan(
          text: costText,
          style: TextStyle(
            color: Colors.white,
            fontSize: baseFontSize * 0.7,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      costPainter.layout();
      costPainter.paint(
        canvas,
        Offset(
          hintButtonRect.center.dx - costPainter.width / 2,
          hintButtonRect.center.dy + hintButtonSize * 0.3,
        ),
      );
    }

    // Draw rules icon button
    final rulesButtonSize = 50.0 * smallScaleFactor;
    final rulesButtonRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x - rulesButtonSize / 2 - 10, panelHeight / 2 + 10),
        width: rulesButtonSize,
        height: rulesButtonSize,
      ),
      Radius.circular(rulesButtonSize / 2),
    );

    canvas.drawRRect(
      rulesButtonRect.inflate(2),
      Paint()
        ..color = Colors.green[400]!.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4),
    );

    canvas.drawRRect(
      rulesButtonRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.green[700]!.withOpacity(0.9),
            Colors.green[500]!.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rulesButtonRect.outerRect),
    );

    final rulesIconPainter = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: baseFontSize * 1.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    rulesIconPainter.layout();
    rulesIconPainter.paint(
      canvas,
      Offset(
        size.x - rulesButtonSize / 2 - 10 - rulesIconPainter.width / 2,
        panelHeight / 2 + 10 - rulesIconPainter.height / 2,
      ),
    );

    // Draw power-up indicators
    if (hasExplosivePowerUp || hasColorMatchPowerUp) {
      final powerUpRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x / 2 - panelWidth - 60, 10, panelWidth, panelHeight),
        Radius.circular(panelHeight / 2),
      );

      canvas.drawRRect(
        powerUpRect.inflate(2),
        Paint()
          ..color = Colors.purple[400]!.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4),
      );

      canvas.drawRRect(
        powerUpRect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.purple[900]!.withOpacity(0.7),
              Colors.purple[700]!.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(powerUpRect.outerRect),
      );

      final iconSize = 20.0 * smallScaleFactor;
      var xOffset = size.x / 2 - panelWidth - 50;

      if (hasExplosivePowerUp) {
        canvas.drawCircle(
          Offset(xOffset + iconSize / 2, 10 + panelHeight / 2),
          iconSize / 2,
          Paint()..color = Colors.orange,
        );
        canvas.drawCircle(
          Offset(xOffset + iconSize / 2, 10 + panelHeight / 2),
          iconSize / 4,
          Paint()..color = Colors.red,
        );
        xOffset += iconSize + 10;
      }

      if (hasColorMatchPowerUp) {
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(xOffset + i * 8 * smallScaleFactor, 10 + panelHeight / 2),
            iconSize / 4,
            Paint()..color = blockColors[i],
          );
        }
      }
    }

    // Draw multiplier text
    if (scoreMultiplier > 1.0) {
      final multiplierText = 'x${scoreMultiplier.toStringAsFixed(1)}';
      final multiplierPainter = TextPainter(
        text: TextSpan(
          text: multiplierText,
          style: TextStyle(
            color: Colors.orange,
            fontSize: baseFontSize * 1.2,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 8,
                color: Colors.orange[300]!.withOpacity(0.7),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      multiplierPainter.layout();
      multiplierPainter.paint(
        canvas, 
        Offset(
          size.x / 2 + panelWidth / 2 + 10,
          10 + (panelHeight - multiplierPainter.height) / 2,
        ),
      );
    }

    // Draw score text
    final scoreText = 'Score: $displayScore';
    final textPainter = TextPainter(
      text: TextSpan(
        text: scoreText,
        style: TextStyle(
          color: Colors.white,
          fontSize: baseFontSize * 1.5,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 12,
              color: Colors.blue[300]!.withOpacity(0.7),
              offset: const Offset(0, 0),
            ),
            Shadow(
              blurRadius: 4,
              color: Colors.white.withOpacity(0.5),
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textX = size.x / 2 - textPainter.width / 2;
    final textY = 10 + (panelHeight - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));

    // Draw continue prompt if needed
    if (showContinuePrompt) {
      _drawContinuePrompt(canvas, baseFontSize);
    }
  }

  void _drawLampIcon(Canvas canvas, Offset center, bool isActive) {
    final iconSize = 20.0 * smallScaleFactor;
    final iconColor = isActive ? Colors.yellow : Colors.grey;
    
    final bulbPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, iconSize * 0.4, bulbPaint);
    
    if (isActive) {
      final rayPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      for (int i = 0; i < 4; i++) {
        final angle = i * pi / 2;
        final start = center;
        final end = center + Offset(cos(angle), sin(angle)) * iconSize * 0.8;
        canvas.drawLine(start, end, rayPaint);
      }
    }
    
    final standPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;
    
    final standRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + iconSize * 0.3),
      width: iconSize * 0.3,
      height: iconSize * 0.4,
    );
    
    canvas.drawRect(standRect, standPaint);
  }

  void _drawAiFeedback(Canvas canvas) {
    final feedbackPainter = TextPainter(
      text: TextSpan(
        text: aiFeedback,
        style: TextStyle(
          color: feedbackColor.withOpacity(feedbackOpacity),
          fontSize: 20.0 * scaleFactor,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.7),
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    feedbackPainter.layout();
    
    final feedbackX = size.x / 2 - feedbackPainter.width / 2;
    final feedbackY = size.y / 2 - 50;
    
    feedbackPainter.paint(canvas, Offset(feedbackX, feedbackY));
  }

  void _drawContinuePrompt(Canvas canvas, double baseFontSize) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    final promptWidth = min(400.0, size.x * 0.8);
    final promptHeight = min(200.0, size.y * 0.3);

    final promptRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: promptWidth,
        height: promptHeight,
      ),
      Radius.circular(promptHeight * 0.1),
    );

    canvas.drawRRect(
      promptRect.inflate(4),
      Paint()
        ..color = Colors.blue[400]!.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
    );

    canvas.drawRRect(
      promptRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.blue[900]!.withOpacity(0.9),
            Colors.blue[700]!.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(promptRect.outerRect),
    );

    final promptFontSize = min(24.0, baseFontSize * 1.2);
    if (score % 2 == 0) {
      final promptText =
          'Continue game for $continueCost points?\nTime remaining: ${continuePromptTimer.toStringAsFixed(1)}s';
      final promptPainter = TextPainter(
        text: TextSpan(
          text: promptText,
          style: TextStyle(
            color: Colors.white,
            fontSize: promptFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      promptPainter.layout(maxWidth: promptWidth - 40);
      promptPainter.paint(
        canvas,
        Offset(
          size.x / 2 - promptPainter.width / 2,
          size.y / 2 - promptPainter.height - promptHeight * 0.2,
        ),
      );

      final buttonWidth = min(120.0, promptWidth * 0.3);
      final buttonHeight = min(50.0, promptHeight * 0.25);

      final yesRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.x / 2 - buttonWidth * 0.8, size.y / 2 + promptHeight * 0.2),
          width: buttonWidth,
          height: buttonHeight,
        ),
        Radius.circular(buttonHeight / 2),
      );

      canvas.drawRRect(
        yesRect.inflate(2),
        Paint()
          ..color = Colors.green[400]!.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4),
      );

      canvas.drawRRect(
        yesRect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.green[700]!.withOpacity(0.9),
              Colors.green[500]!.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(yesRect.outerRect),
      );

      final noRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.x / 2 + buttonWidth * 0.8, size.y / 2 + promptHeight * 0.2),
          width: buttonWidth,
          height: buttonHeight,
        ),
        Radius.circular(buttonHeight / 2),
      );

      canvas.drawRRect(
        noRect.inflate(2),
        Paint()
          ..color = Colors.red[400]!.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4),
      );

      canvas.drawRRect(
        noRect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.red[700]!.withOpacity(0.9),
              Colors.red[500]!.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(noRect.outerRect),
      );

      final yesPainter = TextPainter(
        text: const TextSpan(
          text: 'Yes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      yesPainter.layout();
      yesPainter.paint(
        canvas,
        Offset(
          size.x / 2 - buttonWidth * 0.8 - yesPainter.width / 2,
          size.y / 2 + promptHeight * 0.2 - yesPainter.height / 2,
        ),
      );

      final noPainter = TextPainter(
        text: const TextSpan(
          text: 'No',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      noPainter.layout();
      noPainter.paint(
        canvas,
        Offset(
          size.x / 2 + buttonWidth * 0.8 - noPainter.width / 2,
          size.y / 2 + promptHeight * 0.2 - noPainter.height / 2,
        ),
      );
    } else {
      final promptText = 'Cannot continue with odd score: $score\nGame Over!';
      final promptPainter = TextPainter(
        text: TextSpan(
          text: promptText,
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: promptFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      promptPainter.layout(maxWidth: promptWidth - 40);
      promptPainter.paint(
        canvas,
        Offset(
          size.x / 2 - promptPainter.width / 2,
          size.y / 2 - promptPainter.height / 2,
        ),
      );
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (draggingBlock != null) {
      draggingBlock!.position += Offset(
        info.delta.global.x,
        info.delta.global.y,
      );

      final blockCenter = Offset(
        draggingBlock!.position.dx + (draggingBlock!.shape[0].length * cellSize) / 2,
        draggingBlock!.position.dy + (draggingBlock!.shape.length * cellSize) / 2,
      );

      final gridPos = getGridPosition(blockCenter);
      if (gridPos != null) {
        final (startX, startY) = gridPos;
        final adjustedX = (startX - draggingBlock!.shape[0].length ~/ 2).clamp(
          0, gridSize - draggingBlock!.shape[0].length,
        );
        final adjustedY = (startY - draggingBlock!.shape.length ~/ 2).clamp(
          0, gridSize - draggingBlock!.shape.length,
        );

        currentGridPosition = (adjustedX, adjustedY);
        isValidPosition = canPlace(draggingBlock!.shape, adjustedX, adjustedY);

        if (isValidPosition) {
          previewOpacity = min(0.5, previewOpacity + 0.1);
        } else {
          previewOpacity = max(0.1, previewOpacity - 0.1);
        }
      } else {
        currentGridPosition = null;
        previewOpacity = max(0.0, previewOpacity - 0.1);
      }
    }
  }

  (int, int)? getGridPosition(Offset position) {
    final gridWidth = gridSize * cellSize + (gridSize - 1) * cellPadding;
    final gridLeft = (size.x - gridWidth) / 2;
    final gridHeight = gridSize * cellSize + (gridSize - 1) * cellPadding;
    final gridTop = gridPadding;

    if (position.dx < gridLeft ||
        position.dx > gridLeft + gridWidth ||
        position.dy < gridTop ||
        position.dy > gridTop + gridHeight) {
      return null;
    }

    int x = ((position.dx - gridLeft) / (cellSize + cellPadding)).floor();
    int y = ((position.dy - gridTop) / (cellSize + cellPadding)).floor();

    if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
      return (x, y);
    }
    return null;
  }

  @override
  void onPanDown(DragDownInfo info) {
    if (showContinuePrompt) {
      final touchX = info.eventPosition.global.x;
      final touchY = info.eventPosition.global.y;

      if (score % 2 == 0) {
        final buttonWidth = min(120.0, size.x * 0.3);
        final yesButtonRect = Rect.fromCenter(
          center: Offset(size.x / 2 - buttonWidth * 0.8, size.y / 2 + (min(200.0, size.y * 0.3)) * 0.2),
          width: buttonWidth,
          height: min(50.0, size.y * 0.08),
        );

        final noButtonRect = Rect.fromCenter(
          center: Offset(size.x / 2 + buttonWidth * 0.8, size.y / 2 + (min(200.0, size.y * 0.3)) * 0.2),
          width: buttonWidth,
          height: min(50.0, size.y * 0.08),
        );

        if (yesButtonRect.contains(Offset(touchX, touchY))) {
          continueGame();
        } else if (noButtonRect.contains(Offset(touchX, touchY))) {
          startNewGame();
        }
      } else {
        startNewGame();
      }
      return;
    }

    final touch = Offset(
      info.eventPosition.global.x,
      info.eventPosition.global.y,
    );

    // Check if hint button was tapped
    final hintButtonSize = 50.0 * smallScaleFactor;
    final hintButtonRect = Rect.fromCenter(
      center: Offset(hintButtonSize / 2 + 10, (40.0 * smallScaleFactor) / 2 + 10),
      width: hintButtonSize,
      height: hintButtonSize,
    );
    
    if (hintButtonRect.contains(touch) && isHintAvailable) {
      activateHint();
      return;
    }

    // Check if rules icon button was tapped
    final rulesButtonSize = 50.0 * smallScaleFactor;
    final rulesButtonRect = Rect.fromCenter(
      center: Offset(size.x - rulesButtonSize / 2 - 10, (40.0 * smallScaleFactor) / 2 + 10),
      width: rulesButtonSize,
      height: rulesButtonSize,
    );
    if (rulesButtonRect.contains(touch)) {
      overlays.add('rules');
      return;
    }

    for (var block in bottomBlocks) {
      Rect blockRect = Rect.fromLTWH(
        block.position.dx,
        block.position.dy,
        block.shape[0].length * cellSize,
        block.shape.length * cellSize,
      );
      if (blockRect.contains(touch)) {
        draggingBlock = block;
        block.isDragging = true;
        currentGridPosition = null;
        previewOpacity = 0.0;
        break;
      }
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (draggingBlock != null) {
      final blockCenter = Offset(
        draggingBlock!.position.dx + (draggingBlock!.shape[0].length * cellSize) / 2,
        draggingBlock!.position.dy + (draggingBlock!.shape.length * cellSize) / 2,
      );

      final gridPos = getGridPosition(blockCenter);

      if (gridPos != null) {
        final (startX, startY) = gridPos;
        final adjustedX = (startX - draggingBlock!.shape[0].length ~/ 2).clamp(
          0, gridSize - draggingBlock!.shape[0].length,
        );
        final adjustedY = (startY - draggingBlock!.shape.length ~/ 2).clamp(
          0, gridSize - draggingBlock!.shape.length,
        );

        if (canPlace(draggingBlock!.shape, adjustedX, adjustedY)) {
          _analyzeMove(draggingBlock!, adjustedX, adjustedY);
          placeBlock(draggingBlock!.shape, adjustedX, adjustedY);
          score += 5;
          checkFullLines();

          bottomBlocks.removeWhere((block) => block == draggingBlock);
          placedBlockCount++;

          if (placedBlockCount >= 3) {
            generateBottomBlocks();
          }
        } else {
          final index = bottomBlocks.indexOf(draggingBlock!);
          if (index != -1) {
            _positionBottomBlocks();
          }
        }
      } else {
        final index = bottomBlocks.indexOf(draggingBlock!);
        if (index != -1) {
          _positionBottomBlocks();
        }
      }

      draggingBlock!.isDragging = false;
      draggingBlock = null;
    }
  }

  bool canPlace(List<List<int>> shape, int startX, int startY) {
    if (startX < 0 ||
        startY < 0 ||
        startX + shape[0].length > gridSize ||
        startY + shape.length > gridSize) {
      return false;
    }

    for (int y = 0; y < shape.length; y++) {
      for (int x = 0; x < shape[y].length; x++) {
        if (shape[y][x] == 1) {
          int gx = startX + x;
          int gy = startY + y;
          if (grid[gy][gx] != null) {
            return false;
          }
        }
      }
    }
    return true;
  }

  void placeBlock(List<List<int>> shape, int startX, int startY) {
    if (draggingBlock == null) return;

    for (int y = 0; y < shape.length; y++) {
      for (int x = 0; x < shape[y].length; x++) {
        if (shape[y][x] == 1) {
          final gridWidth = gridSize * cellSize + (gridSize - 1) * cellPadding;
          final gridLeft = (size.x - gridWidth) / 2;
          final gridHeight = gridSize * cellSize + (gridSize - 1) * cellPadding;
          final gridTop = gridPadding;

          final effectPosition = Offset(
            gridLeft + (startX + x) * (cellSize + cellPadding),
            gridTop + (startY + y) * (cellSize + cellPadding),
          );

          blockPlacementEffects.add((
            position: effectPosition,
            color: draggingBlock!.color,
            scale: 1.2,
            opacity: 1.0,
          ));

          grid[startY + y][startX + x] = draggingBlock!.color;
        }
      }
    }

    scoreAnimationScale = 1.5;
    lastScoreColor = draggingBlock!.color;
  }

  void checkFullLines() {
    int completedRows = 0;
    int completedColumns = 0;
    int completedSquares = 0;

    checkPatterns();

    for (int y = 0; y < gridSize - 2; y++) {
      for (int x = 0; x < gridSize - 2; x++) {
        bool isFullSquare = true;
        Color? firstColor = grid[y][x];
        if (firstColor == null) continue;

        for (int dy = 0; dy < 3; dy++) {
          for (int dx = 0; dx < 3; dx++) {
            if (grid[y + dy][x + dx] != firstColor) {
              isFullSquare = false;
              break;
            }
          }
          if (!isFullSquare) break;
        }

        if (isFullSquare) {
          for (int dy = 0; dy < 3; dy++) {
            for (int dx = 0; dx < 3; dx++) {
              grid[y + dy][x + dx] = null;
              cellClearEffects.add((
                row: y + dy,
                col: x + dx,
                scale: 1.0,
                opacity: 1.0,
              ));
            }
          }
          completedSquares++;

          if (Random().nextBool()) {
            hasExplosivePowerUp = true;
          } else {
            hasColorMatchPowerUp = true;
          }
        }
      }
    }

    for (int y = 0; y < gridSize; y++) {
      if (grid[y].every((cell) => cell != null)) {
        completedRows++;
        _playGoodSound();
        
        for (int x = 0; x < gridSize; x++) {
          final color = grid[y][x]!;
          cellClearEffects.add((row: y, col: x, scale: 1.0, opacity: 1.0));

          for (int i = 0; i < 3; i++) {
            final spark = (
              row: (y + (Random().nextDouble() - 0.5) * 0.5).round(),
              col: (x + (Random().nextDouble() - 0.5) * 0.5).round(),
              scale: 0.3,
              opacity: 1.0,
            );
            cellClearEffects.add(spark);
          }

          blockPlacementEffects.add((
            position: Offset(
              (size.x - gridSize * cellSize) / 2 + x * (cellSize + cellPadding),
              gridPadding + y * (cellSize + cellPadding),
            ),
            color: color,
            scale: 1.5,
            opacity: 0.8,
          ));
        }

        Future.delayed(const Duration(milliseconds: 200), () {
          grid[y] = List.filled(gridSize, null);
        });
      }
    }

    for (int x = 0; x < gridSize; x++) {
      bool fullCol = true;
      for (int y = 0; y < gridSize; y++) {
        if (grid[y][x] == null) {
          fullCol = false;
          break;
        }
      }

      if (fullCol) {
        completedColumns++;
        _playGoodSound();
        
        for (int y = 0; y < gridSize; y++) {
          final color = grid[y][x]!;
          cellClearEffects.add((row: y, col: x, scale: 1.0, opacity: 1.0));

          for (int i = 0; i < 3; i++) {
            final spark = (
              row: (y + (Random().nextDouble() - 0.5) * 0.5).round(),
              col: (x + (Random().nextDouble() - 0.5) * 0.5).round(),
              scale: 0.3,
              opacity: 1.0,
            );
            cellClearEffects.add(spark);
          }

          blockPlacementEffects.add((
            position: Offset(
              (size.x - gridSize * cellSize) / 2 + x * (cellSize + cellPadding),
              gridPadding + y * (cellSize + cellPadding),
            ),
            color: color,
            scale: 1.5,
            opacity: 0.8,
          ));
        }

        Future.delayed(const Duration(milliseconds: 200), () {
          for (int y = 0; y < gridSize; y++) {
            grid[y][x] = null;
          }
        });
      }
    }

    int totalClears = completedRows + completedColumns + completedSquares;
    double chainBonus = totalClears > 1 ? totalClears * 0.5 : 1.0;

    double timeBonus = 1.0;
    if (lastPlacementTime != null) {
      final timeDiff = DateTime.now().difference(lastPlacementTime!).inSeconds;
      if (timeDiff < 3) {
        timeBonus = 1.5;
      }
    }
    lastPlacementTime = DateTime.now();

    if (totalClears > 0) {
      consecutivePlacements++;
      scoreMultiplier = min(3.0, 1.0 + (consecutivePlacements * 0.2));
    } else {
      consecutivePlacements = 0;
      scoreMultiplier = 1.0;
    }

    int baseScore = (completedRows + completedColumns) * 20 + completedSquares * 50;
    int finalScore = (baseScore * chainBonus * timeBonus * scoreMultiplier).round();

    if (finalScore > 0) {
      score += finalScore;
    }
  }

  void checkPatterns() {
    for (int y = 0; y < gridSize; y++) {
      Set<Color> colors = {};
      for (int x = 0; x < gridSize; x++) {
        if (grid[y][x] != null) {
          colors.add(grid[y][x]!);
        }
      }
      if (colors.length == gridSize) {
        hasRainbowPattern = true;
        score += 100;
      }
    }

    bool isFrame = true;
    for (int i = 0; i < gridSize; i++) {
      if (grid[0][i] == null ||
          grid[gridSize - 1][i] == null ||
          grid[i][0] == null ||
          grid[i][gridSize - 1] == null) {
        isFrame = false;
        break;
      }
    }
    if (isFrame) {
      hasFramePattern = true;
      score += 150;
    }

    bool hasDiagonal = true;
    for (int i = 0; i < gridSize; i++) {
      if (grid[i][i] == null) {
        hasDiagonal = false;
        break;
      }
    }
    if (hasDiagonal) {
      hasDiagonalLine = true;
      score += 200;
    }
  }

  void showFloatingText(String text, Color color) {
    // Floating text implementation can be added here
  }
}

extension on Offset {
  Offset get normalized {
    final length = sqrt(dx * dx + dy * dy);
    return length == 0 ? this : Offset(dx / length, dy / length);
  }
}