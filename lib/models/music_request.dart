// music_request.dart
class MusicRequest {
  final String lrc;
  final String? textPrompt;
  final int seed;
  final bool randomizeSeed;
  final int steps;
  final double cfgStrength;
  final String fileType;
  final String odeintMethod;
  final String musicDuration;

  MusicRequest({
    required this.lrc,
    this.textPrompt,
    this.seed = 42,
    this.randomizeSeed = false,
    this.steps = 32,
    this.cfgStrength = 4.0,
    this.fileType = "wav",
    this.odeintMethod = "euler",
    this.musicDuration = "95s",
  });

  Map<String, dynamic> toJson() => {
    'lrc': lrc,
    'text_prompt': textPrompt,
    'seed': seed,
    'randomize_seed': randomizeSeed,
    'steps': steps,
    'cfg_strength': cfgStrength,
    'file_type': fileType,
    'odeint_method': odeintMethod,
    'music_duration': musicDuration,
  };
}