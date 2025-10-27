import 'package:flutter/material.dart';
import 'game_screen.dart';

class RulesScreen extends StatelessWidget {
  final BlockBlastGame game;
  const RulesScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 520,
          height: 560,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.blueGrey[900],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 12)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rules', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () {
                      game.overlays.remove('rules');
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('• Place the falling blocks on the 10x10 grid. Each placement gives +5 points.'),
                        SizedBox(height: 8),
                        Text('• Complete full rows or columns to clear them and gain points.'),
                        SizedBox(height: 8),
                        Text('• Completing special 3x3 color squares grants power-ups (explosive or color-match).'),
                        SizedBox(height: 8),
                        Text('• Power-ups can trigger extra clears or slow time temporarily.'),
                        SizedBox(height: 8),
                        Text('• Hints: purchase a hint for 50 points. A single placement suggestion will be shown for a short time.'),
                        SizedBox(height: 8),
                        Text('• Game modes: Timed (1/2/5 minutes) or Rating (unlimited).'),
                        SizedBox(height: 8),
                        Text('• Continue: when no moves are available you can continue by spending half your score or Save to keep full score.'),
                        SizedBox(height: 8),
                        Text('• Try to create combos and patterns for multipliers and bonuses.'),
                        SizedBox(height: 20),
                        Text('Good luck and have fun!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () => game.overlays.remove('rules'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                    child: Text('Close', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
