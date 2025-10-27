import 'package:block_blast/game_screen.dart';
import 'package:block_blast/rules_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: GameWidget(
          game: BlockBlastGame(),
          overlayBuilderMap: {
            'rules': (context, game) =>
                RulesScreen(game: game as BlockBlastGame),
          },
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: GameWidget(game: BlockBlastGame())),
    );
  }
}
