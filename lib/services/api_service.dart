// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
//
// class ApiService {
//   static const String baseUrl = 'https://your-api-url.com';
//
//   Future<File> generateMusic(MusicRequest request, File? audioFile) async {
//     var uri = Uri.parse('$baseUrl/generate_music/');
//     var requestMultipart = http.MultipartRequest('POST', uri);
//
//     requestMultipart.fields.addAll(request.toJson().map((key, value) => MapEntry(key, value.toString())));
//     if (audioFile != null) {
//       requestMultipart.files.add(await http.MultipartFile.fromPath('audio_file', audioFile.path));
//     }
//
//     var response = await requestMultipart.send();
//     if (response.statusCode == 200) {
//       var tempDir = Directory.systemTemp;
//       var tempFile = File('${tempDir.path}/generated_music.${request.fileType}');
//       await tempFile.writeAsBytes(await response.stream.toBytes());
//       return tempFile;
//     } else {
//       throw Exception('Failed to generate music: ${response.statusCode}');
//     }
//   }
//
//   Future<String> generateLyricsTheme(LyricsThemeRequest request) async {
//     var response = await http.post(
//       Uri.parse('$baseUrl/generate_lyrics_theme/'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode(request.toJson()),
//     );
//     if (response.statusCode == 200) {
//       return jsonDecode(response.body)['lyrics'];
//     } else {
//       throw Exception('Failed to generate lyrics: ${response.statusCode}');
//     }
//   }
//
//   Future<String> generateLyricsTimestamp(LyricsTimestampRequest request) async {
//     var response = await http.post(
//       Uri.parse('$baseUrl/generate_lyrics_timestamp/'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode(request.toJson()),
//     );
//     if (response.statusCode == 200) {
//       return jsonDecode(response.body)['lyrics'];
//     } else {
//       throw Exception('Failed to generate lyrics: ${response.statusCode}');
//     }
//   }
// }