import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class ResultScreen extends StatefulWidget {
  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    String lyrics = args['lyrics']!;
    String style = args['style']!;

    return Scaffold(
      appBar: AppBar(title: Text('Generated Music')),
      body: Column(
        children: [
          Text('Lyrics: $lyrics'),
          Text('Style: $style'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () async {
                  if (_isPlaying) {
                    await _audioPlayer.pause();
                  } else {
                    await _audioPlayer.play(AssetSource('sample_music.mp3'));
                  }
                  setState(() => _isPlaying = !_isPlaying);
                },
              ),
              IconButton(
                icon: Icon(Icons.stop),
                onPressed: () async {
                  await _audioPlayer.stop();
                  setState(() => _isPlaying = false);
                },
              ),
            ],
          ),
          ElevatedButton(onPressed: () {}, child: Text('Download')),
          ElevatedButton(onPressed: () {}, child: Text('Share')),
        ],
      ),
    );
  }
}