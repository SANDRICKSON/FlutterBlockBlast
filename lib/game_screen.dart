import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flame/components.dart';

// Block კლასი
// Special block types for power-ups
enum BlockType {
  normal,
  lineClear, // Clears entire row and column
  colorBomb, // Clears all blocks of same color
  timeSlow, // Slows down timer
  shrink, // Can be placed in smaller spaces
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
    // Random chance to create special blocks
    if (Random().nextDouble() < 0.15) {
      // 15% chance for special block
      type = BlockType.values[Random().nextInt(BlockType.values.length)];

      // Adjust appearance based on type
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

    // Animate block appearance
    _startEntryAnimation();
  }

  void _startEntryAnimation() {
    // Animate from scale 0 to 1 with bounce
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
  double cellSize = 50; // Responsive structure, but always fixed
  double cellPadding = 4;
  double gridPadding = 40;
  double bottomBlocksY = 650;

  // Achievement tracking
  int highScore = 0;
  int maxCombo = 0;
  int totalLinesCleared = 0;
  int specialPatternsFound = 0;

  // Combo system
  int currentCombo = 0;
  double comboTimer = 0.0;
  static const double comboTimeWindow =
      3.0; // Time window for maintaining combo

  // Power-up effects
  bool isTimeSlowed = false;
  double timeSlowDuration = 0.0;
  static const double timeSlowFactor = 0.5; // Timer runs at half speed

  // Pattern recognition
  bool hasRainbowPattern = false; // All colors in a row/column
  bool hasFramePattern = false; // Blocks around the edge
  bool hasDiagonalLine = false; // Complete diagonal line

  // Properties for placement preview
  (int, int)? currentGridPosition; // Current grid position while dragging
  double previewOpacity = 0.0; // Opacity for the preview effect
  bool isValidPosition = false; // Whether current position is valid

  bool showContinuePrompt = false;
  double continuePromptTimer = 5.0;
  bool canContinue = true;

  // Animation properties
  List<({Offset position, Color color, double scale, double opacity})>
  blockPlacementEffects = [];
  List<({int row, int col, double scale, double opacity})> cellClearEffects =
      [];
  double scoreAnimationScale = 1.0;
  Color? lastScoreColor;
  int displayScore = 0; // For smooth score animation

  // Modern color palette for blocks
  static final List<Color> blockColors = [
    const Color(0xFF2196F3), // Vibrant Blue
    const Color(0xFFE91E63), // Pink
    const Color(0xFF4CAF50), // Material Green
    const Color(0xFFFF9800), // Orange
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFFFEB3B), // Yellow
    const Color(0xFF673AB7), // Deep Purple
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

  @override
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Always set fixed values, even if screen size changes
    cellSize = 50;
    cellPadding = 4;
    gridPadding = 40;
    bottomBlocksY = 650;
    generateBottomBlocks();
  }

  void generateBottomBlocks() {
    bottomBlocks = List.generate(3, (_) => Block(randomShape(), Offset(0, 0)));

    // Calculate total width of bottom blocks to center them
    double totalWidth = 0;
    for (var block in bottomBlocks) {
      totalWidth += block.shape[0].length * (cellSize + cellPadding);
    }
    totalWidth +=
        (bottomBlocks.length - 1) * cellSize; // spacing between blocks

    double startX = (size.x - totalWidth) / 2;
    for (int i = 0; i < bottomBlocks.length; i++) {
      double blockWidth =
          bottomBlocks[i].shape[0].length * (cellSize + cellPadding);
      bottomBlocks[i].position = Offset(startX, bottomBlocksY);
      startX += blockWidth + cellSize; // Add space between blocks
    }
    placedBlockCount = 0;
  }

  List<List<int>> randomShape() {
    int type = random.nextInt(20); // Increased number of block types
    switch (type) {
      case 0: // Single block
        return [
          [1],
        ];
      case 1: // Horizontal duo
        return [
          [1, 1],
        ];
      case 2: // Vertical duo
        return [
          [1],
          [1],
        ];
      case 3: // Square
        return [
          [1, 1],
          [1, 1],
        ];
      case 4: // Horizontal trio
        return [
          [1, 1, 1],
        ];
      case 5: // L shape
        return [
          [1, 0],
          [1, 0],
          [1, 1],
        ];
      case 6: // Reverse L shape
        return [
          [0, 1],
          [0, 1],
          [1, 1],
        ];
      case 7: // T shape
        return [
          [1, 1, 1],
          [0, 1, 0],
        ];
      case 8: // S shape
        return [
          [0, 1, 1],
          [1, 1, 0],
        ];
      case 9: // Z shape
        return [
          [1, 1, 0],
          [0, 1, 1],
        ];
      case 10: // Long piece
        return [
          [1],
          [1],
          [1],
          [1],
        ];
      case 11: // Plus shape
        return [
          [0, 1, 0],
          [1, 1, 1],
          [0, 1, 0],
        ];
      // New 3x3 Blocks
      case 12: // 3x3 Full Square
        return [
          [1, 1, 1],
          [1, 1, 1],
          [1, 1, 1],
        ];
      case 13: // U Shape
        return [
          [1, 0, 1],
          [1, 0, 1],
          [1, 1, 1],
        ];
      case 14: // H Shape
        return [
          [1, 0, 1],
          [1, 1, 1],
          [1, 0, 1],
        ];
      case 15: // Cross Shape
        return [
          [1, 0, 1],
          [0, 1, 0],
          [1, 0, 1],
        ];
      case 16: // Window Shape
        return [
          [1, 1, 1],
          [1, 0, 1],
          [1, 1, 1],
        ];
      case 17: // C Shape
        return [
          [1, 1, 1],
          [1, 0, 0],
          [1, 1, 1],
        ];
      case 18: // Diagonal Shape
        return [
          [1, 0, 0],
          [0, 1, 0],
          [0, 0, 1],
        ];
      case 19: // Corner Frame
        return [
          [1, 1, 0],
          [1, 0, 0],
          [1, 1, 1],
        ];
      default:
        return [
          [1],
        ];
    }
  }

  bool canPlaceAnyBlock() {
    // Check if any block can be placed anywhere on the grid
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

    // Update cell clear effects with enhanced animations
    final now = DateTime.now().millisecondsSinceEpoch / 300.0;

    for (int i = cellClearEffects.length - 1; i >= 0; i--) {
      var effect = cellClearEffects[i];

      // Add wave animation
      double waveOffset = sin(now + effect.col * 0.5) * 4.0;

      // Update with wave and pulse effects
      effect = (
        row: (effect.row + waveOffset * 0.1).round(), // Apply wave offset
        col: effect.col,
        scale: effect.scale + dt * 2 + sin(now * 4) * 0.1, // Pulsing scale
        opacity: effect.opacity - dt * 1.5, // Slower fade out
      );

      if (effect.opacity <= 0) {
        cellClearEffects.removeAt(i);
      } else {
        cellClearEffects[i] = effect;

        // Add sparkle effects
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

    // Animate score
    if (scoreAnimationScale > 1.0) {
      scoreAnimationScale = max(1.0, scoreAnimationScale - dt * 2);
    }
    if (displayScore < score) {
      displayScore = min(
        score,
        displayScore + (score - displayScore) ~/ 10 + 1,
      );
    }

    if (showContinuePrompt) {
      continuePromptTimer -= dt;
      if (continuePromptTimer <= 0) {
        if (score % 2 == 0) {
          startNewGame(); // Start new game if timer runs out
        } else {
          // For odd scores, just clear everything
          bottomBlocks.clear();
          showContinuePrompt = false;
          continuePromptTimer = 5.0;
        }
      }
    }

    // Check if game is over (no blocks and not showing prompt)
    if (bottomBlocks.isEmpty && !showContinuePrompt) {
      // Start new game after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        startNewGame();
      });
    }

    // Check if no moves are possible
    if (!showContinuePrompt && bottomBlocks.isNotEmpty && !canPlaceAnyBlock()) {
      showContinuePrompt = true;
      continuePromptTimer = 5.0;
      canContinue = true;
    }

    // Update block animations
    for (var block in bottomBlocks) {
      if (block.scale < 1.0) {
        block.scale = min(1.0, block.scale + dt * 5);
      }
      if (block.opacity < 1.0) {
        block.opacity = min(1.0, block.opacity + dt * 5);
      }
    }
  }

  void continueGame() {
    if (score % 2 == 0) {
      // Only allow continue if score is even
      score = score ~/ 2; // Deduct 50% of score
      showContinuePrompt = false;
      continuePromptTimer = 5.0;
      generateBottomBlocks(); // Generate new blocks
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
          const Color(0xFF1A237E), // Deep Indigo
          const Color(0xFF0D47A1), // Dark Blue
          const Color(0xFF1A237E), // Deep Indigo
        ],
        stops: [0.0, (sin(now) + 1) / 2, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Add subtle pattern overlay
    for (int i = 0; i < size.x; i += 20) {
      for (int j = 0; j < size.y; j += 20) {
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
    final gridTop =
        (size.y - gridHeight) / 4; // Position grid at 1/4 of remaining space

    // Draw grid background with gradient
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final cellRect = Rect.fromLTWH(
          gridLeft + x * (cellSize + cellPadding),
          gridTop + y * (cellSize + cellPadding),
          cellSize,
          cellSize,
        );

        // Draw cell background with modern glass effect
        final cellPaint = Paint()..color = Colors.white.withOpacity(0.05);

        // Draw cell border glow
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            cellRect.inflate(1),
            const Radius.circular(10),
          ),
          Paint()
            ..color = Colors.white.withOpacity(0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2),
        );

        // Draw main cell
        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect, const Radius.circular(8)),
          cellPaint,
        );

        // Draw inner highlight
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cellRect.left + 1,
              cellRect.top + 1,
              cellRect.width - 2,
              cellRect.height - 2,
            ),
            const Radius.circular(7),
          ),
          Paint()..color = Colors.white.withOpacity(0.05),
        );

        // Draw placed blocks
        if (grid[y][x] != null) {
          final blockPaint = Paint()
            ..color = grid[y][x]!
            ..style = PaintingStyle.fill;

          // Draw block shadow
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              cellRect.translate(2, 2),
              const Radius.circular(8),
            ),
            Paint()..color = Colors.black.withOpacity(0.3),
          );

          // Draw block with rounded corners and gradient
          canvas.drawRRect(
            RRect.fromRectAndRadius(cellRect, const Radius.circular(8)),
            blockPaint,
          );

          // Draw highlight
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                cellRect.left + 2,
                cellRect.top + 2,
                cellRect.width - 4,
                cellRect.height - 4,
              ),
              const Radius.circular(6),
            ),
            Paint()..color = Colors.white.withOpacity(0.2),
          );
        }
      }
    }

    // Draw preview when dragging
    if (draggingBlock != null && currentGridPosition != null) {
      final (previewX, previewY) = currentGridPosition!;

      // Calculate grid dimensions
      final gridWidth = gridSize * cellSize + (gridSize - 1) * cellPadding;
      final gridLeft = (size.x - gridWidth) / 2;
      final gridHeight = gridSize * cellSize + (gridSize - 1) * cellPadding;
      final gridTop = (size.y - gridHeight) / 4;

      for (int y = 0; y < draggingBlock!.shape.length; y++) {
        for (int x = 0; x < draggingBlock!.shape[y].length; x++) {
          if (draggingBlock!.shape[y][x] == 1) {
            final previewRect = Rect.fromLTWH(
              gridLeft + (previewX + x) * (cellSize + cellPadding),
              gridTop + (previewY + y) * (cellSize + cellPadding),
              cellSize,
              cellSize,
            );

            // Draw preview cell with glow effect
            final glowPaint = Paint()
              ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8)
              ..color = isValidPosition
                  ? draggingBlock!.color.withOpacity(previewOpacity * 0.5)
                  : Colors.red.withOpacity(previewOpacity * 0.5);

            // Draw main preview shape
            canvas.drawRRect(
              RRect.fromRectAndRadius(previewRect, const Radius.circular(8)),
              Paint()
                ..color = isValidPosition
                    ? draggingBlock!.color.withOpacity(previewOpacity * 0.3)
                    : Colors.red.withOpacity(previewOpacity * 0.3),
            );

            // Draw glow
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                previewRect.inflate(4),
                const Radius.circular(10),
              ),
              glowPaint,
            );

            // Draw border
            canvas.drawRRect(
              RRect.fromRectAndRadius(previewRect, const Radius.circular(8)),
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

            // Draw block glow effect
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                blockRect.inflate(2),
                const Radius.circular(10),
              ),
              Paint()
                ..color = block.color.withOpacity(0.3)
                ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3),
            );

            // Draw block with gradient
            final gradientColors =
                blockGradients[block.color] ?? [block.color, block.color];
            final blockPaint = Paint()
              ..shader = LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(blockRect);

            // Draw main block shape
            canvas.drawRRect(
              RRect.fromRectAndRadius(blockRect, const Radius.circular(8)),
              blockPaint,
            );

            // Draw inner highlight
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  blockRect.left + 2,
                  blockRect.top + 2,
                  blockRect.width - 4,
                  blockRect.height - 4,
                ),
                const Radius.circular(6),
              ),
              Paint()..color = Colors.white.withOpacity(0.3),
            );
          }
        }
      }
    }

    // Draw score panel background
    final scorePanelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x / 2 - 100, 10, 200, 50),
      const Radius.circular(25),
    );

    // Draw score panel glow
    canvas.drawRRect(
      scorePanelRect.inflate(2),
      Paint()
        ..color = Colors.blue[400]!.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4),
    );

    // Draw score panel background
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

    // Draw power-up indicators
    if (hasExplosivePowerUp || hasColorMatchPowerUp) {
      final powerUpRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 10, 160, 50),
        const Radius.circular(25),
      );

      // Draw power-up panel background with glow
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

      // Draw power-up icons and text
      final iconSize = 30.0;
      var xOffset = 20.0;

      if (hasExplosivePowerUp) {
        canvas.drawCircle(
          Offset(xOffset + iconSize / 2, 35),
          iconSize / 2,
          Paint()..color = Colors.orange,
        );
        canvas.drawCircle(
          Offset(xOffset + iconSize / 2, 35),
          iconSize / 4,
          Paint()..color = Colors.red,
        );
        xOffset += iconSize + 10;
      }

      if (hasColorMatchPowerUp) {
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(xOffset + i * 10, 35),
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
            fontSize: 24,
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
      multiplierPainter.paint(canvas, Offset(size.x / 2 + 110, 20));
    }

    // Draw score text with glow effect
    final scoreText = 'Score: $displayScore';
    final textPainter = TextPainter(
      text: TextSpan(
        text: scoreText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
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

    // Center the score text in the panel
    final textX = size.x / 2 - textPainter.width / 2;
    final textY = 20.0; // Fixed the int to double conversion
    textPainter.paint(canvas, Offset(textX, textY));

    // Draw continue prompt if needed
    if (showContinuePrompt) {
      // Draw semi-transparent overlay
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.black.withOpacity(0.7),
      );

      // Draw prompt panel
      final promptRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y / 2),
          width: 400,
          height: 200,
        ),
        const Radius.circular(20),
      );

      // Draw panel background with glow
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

      // Draw prompt text and buttons
      if (score % 2 == 0) {
        // Draw prompt text
        final promptText =
            'Continue game for ${score ~/ 2} points?\nTime remaining: ${continuePromptTimer.toStringAsFixed(1)}s';
        final promptPainter = TextPainter(
          text: TextSpan(
            text: promptText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        promptPainter.layout(maxWidth: 360);
        promptPainter.paint(
          canvas,
          Offset(
            size.x / 2 - promptPainter.width / 2,
            size.y / 2 - promptPainter.height - 40,
          ),
        );

        // Draw Yes/No buttons
        final buttonWidth = 120.0;
        final buttonHeight = 50.0;

        // Yes button
        final yesRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.x / 2 - 80, size.y / 2 + 40),
            width: buttonWidth,
            height: buttonHeight,
          ),
          const Radius.circular(25),
        );

        // Draw yes button with glow
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

        // No button
        final noRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.x / 2 + 80, size.y / 2 + 40),
            width: buttonWidth,
            height: buttonHeight,
          ),
          const Radius.circular(25),
        );

        // Draw no button with glow
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

        // Draw button text
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
            size.x / 2 - 80 - yesPainter.width / 2,
            size.y / 2 + 40 - yesPainter.height / 2,
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
            size.x / 2 + 80 - noPainter.width / 2,
            size.y / 2 + 40 - noPainter.height / 2,
          ),
        );
      } else {
        final promptText = 'Cannot continue with odd score: $score\nGame Over!';
        final promptPainter = TextPainter(
          text: TextSpan(
            text: promptText,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        promptPainter.layout(maxWidth: 360);
        promptPainter.paint(
          canvas,
          Offset(
            size.x / 2 - promptPainter.width / 2,
            size.y / 2 - promptPainter.height / 2,
          ),
        );
      }
    }
  }

  // Drag & Drop handling for blocks

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (draggingBlock != null) {
      draggingBlock!.position += Offset(
        info.delta.global.x,
        info.delta.global.y,
      );

      // Calculate current grid position
      final blockCenter = Offset(
        draggingBlock!.position.dx +
            (draggingBlock!.shape[0].length * cellSize) / 2,
        draggingBlock!.position.dy +
            (draggingBlock!.shape.length * cellSize) / 2,
      );

      final gridPos = getGridPosition(blockCenter);
      if (gridPos != null) {
        final (startX, startY) = gridPos;

        // Adjust position based on block size
        final adjustedX = (startX - draggingBlock!.shape[0].length ~/ 2).clamp(
          0,
          gridSize - draggingBlock!.shape[0].length,
        );
        final adjustedY = (startY - draggingBlock!.shape.length ~/ 2).clamp(
          0,
          gridSize - draggingBlock!.shape.length,
        );

        currentGridPosition = (adjustedX, adjustedY);
        isValidPosition = canPlace(draggingBlock!.shape, adjustedX, adjustedY);

        // Animate preview opacity based on validity
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

  // Helper method to convert screen position to grid position
  (int, int)? getGridPosition(Offset position) {
    final gridWidth = gridSize * cellSize + (gridSize - 1) * cellPadding;
    final gridLeft = (size.x - gridWidth) / 2;
    final gridHeight = gridSize * cellSize + (gridSize - 1) * cellPadding;
    final gridTop = (size.y - gridHeight) / 4;

    // Check if position is within grid bounds
    if (position.dx < gridLeft ||
        position.dx > gridLeft + gridWidth ||
        position.dy < gridTop ||
        position.dy > gridTop + gridHeight) {
      return null;
    }

    // Calculate grid coordinates
    int x = ((position.dx - gridLeft) / (cellSize + cellPadding)).floor();
    int y = ((position.dy - gridTop) / (cellSize + cellPadding)).floor();

    // Ensure coordinates are within grid bounds
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
        // Define button rectangles
        final yesButtonRect = Rect.fromCenter(
          center: Offset(size.x / 2 - 80, size.y / 2 + 40),
          width: 120,
          height: 50,
        );

        final noButtonRect = Rect.fromCenter(
          center: Offset(size.x / 2 + 80, size.y / 2 + 40),
          width: 120,
          height: 50,
        );

        if (yesButtonRect.contains(Offset(touchX, touchY))) {
          continueGame();
        } else if (noButtonRect.contains(Offset(touchX, touchY))) {
          startNewGame();
        }
      } else {
        // For odd scores, any tap starts a new game
        startNewGame();
      }
      return;
    }

    final touch = Offset(
      info.eventPosition.global.x,
      info.eventPosition.global.y,
    );
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
      // Get the center position of the dragged block
      final blockCenter = Offset(
        draggingBlock!.position.dx +
            (draggingBlock!.shape[0].length * cellSize) / 2,
        draggingBlock!.position.dy +
            (draggingBlock!.shape.length * cellSize) / 2,
      );

      // Convert screen position to grid position
      final gridPos = getGridPosition(blockCenter);

      if (gridPos != null) {
        final (startX, startY) = gridPos;

        // Adjust position based on block size
        final adjustedX = (startX - draggingBlock!.shape[0].length ~/ 2).clamp(
          0,
          gridSize - draggingBlock!.shape[0].length,
        );
        final adjustedY = (startY - draggingBlock!.shape.length ~/ 2).clamp(
          0,
          gridSize - draggingBlock!.shape.length,
        );

        if (canPlace(draggingBlock!.shape, adjustedX, adjustedY)) {
          placeBlock(draggingBlock!.shape, adjustedX, adjustedY);
          // Add 5 points for successful block placement
          score += 5;
          checkFullLines();

          // Remove the placed block from bottomBlocks
          bottomBlocks.removeWhere((block) => block == draggingBlock);
          placedBlockCount++;

          // Only generate new blocks when all three have been placed
          if (placedBlockCount >= 3) {
            generateBottomBlocks();
          }
        } else {
          // Return block to original position if can't place
          final index = bottomBlocks.indexOf(draggingBlock!);
          if (index != -1) {
            double startX =
                (size.x - (bottomBlocks.length * (cellSize * 3 + cellSize))) /
                2;
            draggingBlock!.position = Offset(
              startX + index * (cellSize * 3 + cellSize),
              bottomBlocksY,
            );
          }
        }
      } else {
        // Return block to original position if outside grid
        final index = bottomBlocks.indexOf(draggingBlock!);
        if (index != -1) {
          double startX =
              (size.x - (bottomBlocks.length * (cellSize * 3 + cellSize))) / 2;
          draggingBlock!.position = Offset(
            startX + index * (cellSize * 3 + cellSize),
            bottomBlocksY,
          );
        }
      }

      draggingBlock!.isDragging = false;
      draggingBlock = null;
    }
  }

  bool canPlace(List<List<int>> shape, int startX, int startY) {
    // Check if the entire shape is within grid bounds
    if (startX < 0 ||
        startY < 0 ||
        startX + shape[0].length > gridSize ||
        startY + shape.length > gridSize) {
      return false;
    }

    // Check if all cells needed are empty
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
          // Add placement effect
          final gridWidth = gridSize * cellSize + (gridSize - 1) * cellPadding;
          final gridLeft = (size.x - gridWidth) / 2;
          final gridHeight = gridSize * cellSize + (gridSize - 1) * cellPadding;
          final gridTop = (size.y - gridHeight) / 4;

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

    // Animate score increase
    scoreAnimationScale = 1.5;
    lastScoreColor = draggingBlock!.color;
  }

  // Score multiplier for consecutive successful placements
  double scoreMultiplier = 1.0;
  int consecutivePlacements = 0;

  // Time tracking for quick placement bonus
  DateTime? lastPlacementTime;

  // Power-up tracking
  bool hasExplosivePowerUp = false;
  bool hasColorMatchPowerUp = false;

  // Check for special patterns
  void checkPatterns() {
    // Check for rainbow pattern (all different colors in line)
    for (int y = 0; y < gridSize; y++) {
      Set<Color> colors = {};
      for (int x = 0; x < gridSize; x++) {
        if (grid[y][x] != null) {
          colors.add(grid[y][x]!);
        }
      }
      if (colors.length == gridSize) {
        hasRainbowPattern = true;
        score += 100; // Bonus for rainbow pattern
        showFloatingText(
          "Rainbow Pattern! +100",
          Color.lerp(
            Colors.red,
            Colors.blue,
            sin(DateTime.now().millisecondsSinceEpoch / 500),
          )!,
        );
      }
    }

    // Check for frame pattern
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
      score += 150; // Bonus for frame pattern
      showFloatingText("Frame Complete! +150", Colors.amber);
    }

    // Check for diagonal line
    bool hasDiagonal = true;
    for (int i = 0; i < gridSize; i++) {
      if (grid[i][i] == null) {
        hasDiagonal = false;
        break;
      }
    }
    if (hasDiagonal) {
      hasDiagonalLine = true;
      score += 200; // Bonus for diagonal line
      showFloatingText("Diagonal Line! +200", Colors.purple);
    }
  }

  void checkFullLines() {
    int completedRows = 0;
    int completedColumns = 0;
    int completedSquares = 0; // For 3x3 square patterns

    // Check for special patterns first
    checkPatterns();

    // Wave animation offset for line clear effects
    final now = DateTime.now().millisecondsSinceEpoch / 300.0;

    // Check for special 3x3 square patterns
    for (int y = 0; y < gridSize - 2; y++) {
      for (int x = 0; x < gridSize - 2; x++) {
        bool isFullSquare = true;
        Color? firstColor = grid[y][x];
        if (firstColor == null) continue;

        // Check if all cells in 3x3 square are filled and match color
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
          // Clear the square and grant power-up
          for (int dy = 0; dy < 3; dy++) {
            for (int dx = 0; dx < 3; dx++) {
              grid[y + dy][x + dx] = null;

              // Add clear effect
              cellClearEffects.add((
                row: y + dy,
                col: x + dx,
                scale: 1.0,
                opacity: 1.0,
              ));
            }
          }
          completedSquares++;

          // Grant power-up for completing a square
          if (Random().nextBool()) {
            hasExplosivePowerUp = true;
          } else {
            hasColorMatchPowerUp = true;
          }
        }
      }
    }

    // Store colors before clearing for effects

    List<Color> rowColors = [];
    List<Color> colColors = [];

    // Check rows
    for (int y = 0; y < gridSize; y++) {
      if (grid[y].every((cell) => cell != null)) {
        // Store colors before clearing
        rowColors = List.from(
          grid[y].where((color) => color != null).cast<Color>(),
        );

        // Add wave effect particles
        for (int x = 0; x < gridSize; x++) {
          final color = grid[y][x]!;
          cellClearEffects.add((row: y, col: x, scale: 1.0, opacity: 1.0));

          // Add sparks
          for (int i = 0; i < 3; i++) {
            final spark = (
              row: (y + (Random().nextDouble() - 0.5) * 0.5).round(),
              col: (x + (Random().nextDouble() - 0.5) * 0.5).round(),
              scale: 0.3,
              opacity: 1.0,
            );
            cellClearEffects.add(spark);
          }

          // Add glow effect
          blockPlacementEffects.add((
            position: Offset(
              (size.x - gridSize * cellSize) / 2 + x * (cellSize + cellPadding),
              (size.y - gridSize * cellSize) / 4 + y * (cellSize + cellPadding),
            ),
            color: color,
            scale: 1.5,
            opacity: 0.8,
          ));
        }

        // Clear row with delay for wave effect
        Future.delayed(const Duration(milliseconds: 200), () {
          grid[y] = List.filled(gridSize, null);
        });

        completedRows++;
      }
    }

    // Check columns
    for (int x = 0; x < gridSize; x++) {
      bool fullCol = true;
      Color? firstColor;
      for (int y = 0; y < gridSize; y++) {
        if (grid[y][x] == null) {
          fullCol = false;
          break;
        }
        if (firstColor == null) firstColor = grid[y][x];
        colColors.add(grid[y][x]!);
      }

      if (fullCol) {
        // Add column clear effects
        for (int y = 0; y < gridSize; y++) {
          final color = grid[y][x]!;
          cellClearEffects.add((row: y, col: x, scale: 1.0, opacity: 1.0));

          // Add vertical spark effects
          for (int i = 0; i < 3; i++) {
            final spark = (
              row: (y + (Random().nextDouble() - 0.5) * 0.5).round(),
              col: (x + (Random().nextDouble() - 0.5) * 0.5).round(),
              scale: 0.3,
              opacity: 1.0,
            );
            cellClearEffects.add(spark);
          }

          // Add glow trail
          blockPlacementEffects.add((
            position: Offset(
              (size.x - gridSize * cellSize) / 2 + x * (cellSize + cellPadding),
              (size.y - gridSize * cellSize) / 4 + y * (cellSize + cellPadding),
            ),
            color: color,
            scale: 1.5,
            opacity: 0.8,
          ));
        }

        // Clear column with delay for cascade effect
        Future.delayed(const Duration(milliseconds: 200), () {
          for (int y = 0; y < gridSize; y++) {
            grid[y][x] = null;
          }
        });

        completedColumns++;
      }
    }

    // Calculate chain reaction bonus
    int totalClears = completedRows + completedColumns + completedSquares;
    double chainBonus = totalClears > 1
        ? totalClears * 0.5
        : 1.0; // 50% bonus per additional clear

    // Calculate time bonus
    double timeBonus = 1.0;
    if (lastPlacementTime != null) {
      final timeDiff = DateTime.now().difference(lastPlacementTime!).inSeconds;
      if (timeDiff < 3) {
        // Quick placement bonus if under 3 seconds
        timeBonus = 1.5;
      }
    }
    lastPlacementTime = DateTime.now();

    // Update score multiplier for consecutive placements
    if (totalClears > 0) {
      consecutivePlacements++;
      scoreMultiplier = min(
        3.0,
        1.0 + (consecutivePlacements * 0.2),
      ); // Max 3x multiplier
    } else {
      consecutivePlacements = 0;
      scoreMultiplier = 1.0;
    }

    // Calculate final score with all bonuses
    int baseScore =
        (completedRows + completedColumns) *
            20 // Base score for lines
            +
        completedSquares * 50; // Extra points for squares

    // Apply all multipliers
    int finalScore = (baseScore * chainBonus * timeBonus * scoreMultiplier)
        .round();

    if (finalScore > 0) {
      score += finalScore;

      // Visual feedback for score multipliers
      if (chainBonus > 1.0) {
        // Show chain reaction text effect
        showFloatingText(
          "Chain x${chainBonus.toStringAsFixed(1)}!",
          Colors.yellow,
        );
      }
      if (timeBonus > 1.0) {
        // Show quick placement bonus text effect
        showFloatingText("Quick! +50%", Colors.green);
      }
      if (scoreMultiplier > 1.0) {
        // Show streak multiplier text effect
        showFloatingText(
          "Streak x${scoreMultiplier.toStringAsFixed(1)}!",
          Colors.orange,
        );
      }
    }
  }

  // Helper method to show floating text effects
  void showFloatingText(String text, Color color) {
    // This will be implemented in the rendering code to show floating text animations
    // The text will float up and fade out
  }
}
