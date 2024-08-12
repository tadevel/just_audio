import 'dart:convert';
import 'dart:core';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:millicent/common.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:text_marquee/text_marquee.dart';
import 'package:transparent_image/transparent_image.dart';

Future<void> main() async {

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  static int _nextMediaId = 0;
  late AudioPlayer _player;
  final _playlist = HlsAudioSource(
      Uri.parse("https://d1i4sik9cp7a6c.cloudfront.net/hls/live.m3u8"),
      tag: MediaItem(
        id: '${_nextMediaId++}',
        album: "",
        title: "millicent",
        artUri: Uri.parse(
            "https://dev.millicent.org/static/imgs/millicent_sized_portrait_flutter.png"),
      ),
    );

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();

  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());


    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.loading) {
        print('A stream is loading');
      } else if (event.processingState == ProcessingState.buffering) {
        print('A stream is buffering');
      }
      if (event.processingState == ProcessingState.completed) {
        _player.stop();
      }
    },
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });

    try {
      await _player.setAudioSource(_playlist);
      await _player.play();
    } on PlayerException catch (e) {
      print("Initialization Error code: ${e.code}");
      print("Initialization Error message: ${e.message}");
    } on PlayerInterruptedException catch (e) {
      /// do stuff
      print("Initialization Connection aborted: ${e.message}");
    } on PlatformException catch (e) {
      _player.stop();
      print("Platform Error $e");
    } catch (e, stackTrace) {
      // Catch load errors: 404, invalid url ...
      print("Error loading playlist: $e");
      print(stackTrace);
    }

  }

  T? ambiguate<T>(T? value) => value;

  @override
  void dispose() {
    ambiguate(WidgetsBinding.instance)!.removeObserver(this as WidgetsBindingObserver);
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print("LIFECYCLE CHANGE");
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      _player.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Container(
            color: Colors.black,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54, width: 0.5),
                color: const Color(0xff131313),
                borderRadius: BorderRadius.circular(6.0), // Rounded inner edges
              ),
              child: Stack(
                alignment: AlignmentDirectional.bottomCenter,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        StreamBuilder<IcyMetadata?>(
                          stream: _player.icyMetadataStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else if (!snapshot.hasData) {
                              return const SizedBox();
                            } else {
                              final metadata = snapshot.data;
                              final jsonString = metadata?.info?.title ?? '';

                              if (jsonString.isNotEmpty) {
                                try {
                                  Map<String, dynamic> jsonData = jsonDecode(jsonString);

                                  var musicTitle = jsonData['music']['title'];
                                  var musicArtist = jsonData['music']['artist'];
                                  var musicUrl = jsonData['music']['source_url'];
                                  var musicImage = (jsonData['music']['image'] != null) ? jsonData['music']['image'] : "";
                                  var fieldTitle = jsonData['field']['title'];
                                  var fieldArtist = jsonData['field']['artist'];
                                  var fieldUrl = jsonData['field']['source_url'];
                                  var vocalTitle = jsonData['vocal']['title'];
                                  var vocalArtist = jsonData['vocal']['artist'];
                                  var vocalUrl = jsonData['vocal']['source_url'];

                                  musicTitle = musicTitle.contains("Error") ? "silence" : musicTitle;
                                  musicArtist = musicTitle.contains("Error") ? "silence" : musicArtist;

                                  return Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (vocalTitle == "silence")
                                          const Spacer(flex: 1,),
                                        if (vocalTitle != "silence")
                                          MetadataContainer(title:'$vocalTitle', artist:'$vocalArtist', image:'', link:'$vocalUrl'),
                                        if (fieldTitle == "silence")
                                          const Spacer(flex: 1),
                                        if (fieldTitle != "silence")
                                          MetadataContainer(title:'$fieldTitle', artist:'$fieldArtist', image:'', link:'$fieldUrl'),
                                        if (musicTitle == "")
                                          const Spacer(flex: 6),
                                        if (musicTitle != "silence")
                                          MetadataContainer(title:'$musicTitle', artist:'$musicArtist', image:'$musicImage', link:'$musicUrl'),
                                      ],
                                    ),
                                  );
                                } catch (e) {
                                  return const Expanded(child: Column());
                                }
                              } else {
                                return const Expanded(child: Column());
                              }
                            }
                          },
                        ),
                        Center(
                          child: Container(
                            color: Colors.transparent,
                            height: 70,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0),
                              child: Container(
                                  decoration: const BoxDecoration(
                                      image: DecorationImage(
                                        isAntiAlias: true,
                                        opacity: 0.7,
                                        image: AssetImage(
                                            "assets/images/millicent_word.png"),
                                      )
                                  )
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            color: const Color(0xff131313),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0, right: 12.0),
                              child: Container(
                                  height: 16,// Margin to create space for the border
                                  decoration: const BoxDecoration(
                                      image: DecorationImage(
                                        isAntiAlias: true,
                                        opacity: 1.0,
                                        image: AssetImage(
                                            "assets/images/rbb.png"),
                                      )
                                  )
                              ),
                            ),
                          ),
                        ),
                        // Display play/pause button and volume/speed sliders.
                        ControlButtons(_player),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      )

    );
  }
}

class MetadataContainer extends StatelessWidget {
  final String title;
  final String artist;
  final String image;
  final String link;

  const MetadataContainer({
    required this.title,
    required this.artist,
    required this.image,
    required this.link,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (image=='') ? 1 : 5,
      child: GestureDetector(
        onTap: () async {
          var urlStr = link.trim();
          if (urlStr.contains("https://www.youtube.com")) {
            urlStr = "$urlStr&mute=1";
          }
          if (urlStr == "") {
            urlStr = "https://duckduckgo.com/?q=$title+$artist";
          }
          var url = Uri.parse(urlStr);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.inAppWebView);
          } else {
            throw 'Could not launch $url';
          }
        },
        child: Column(
          children: [
            if (image != "")
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: FadeInImage.memoryNetwork(
                    key: Key(image),
                    placeholder: kTransparentImage,
                    image: image,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 800),
                    fadeOutDuration: const Duration(milliseconds: 800),
                    imageErrorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.error);
                    },
                  ),
                ),
              ),
            Container(
              width: MediaQuery.of(context).size.width,
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.only(top: 5.0, left: 15.0, right: 15.0),
                child: TextContainer(title: title, artist: artist, image: image, link: link,)
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TextContainer extends StatelessWidget {
  final String title;
  final String artist;
  final String image;
  final String link;

  const TextContainer({
    required this.title,
    required this.artist,
    required this.image,
    required this.link,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (image != '') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.trim(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 25,
                fontFamily: 'Walfork',
                color: const Color(0x90ffffff)
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (artist != "")
            Text(
              artist.trim(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontFamily: 'Tiempos',
                  color: const Color(
                      0xA0ffffff)
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    } else {
      return Center(
        child: SizedBox(
          height: 50,
          width: MediaQuery.of(context).size.width,
          child: TextMarquee(
            key: Key(title),
            '${title.trim()} recorded by ${artist.isNotEmpty ? artist.trim() : "Unknown"}',
            style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w200,
                fontSize: 34
            ),
            duration: const Duration(seconds: 20),
            startPaddingSize: 20,
            delay: const Duration(microseconds: 1),
          ),
        ),
      );
    }
  }
}

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          color: Colors.white38,
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),
        const Spacer(),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const SpinKitDoubleBounce(
                    color: Colors.white54,
                    duration: Duration(seconds: 4),
                ),
              );
            } else if (playing != true) {
              return IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.play_arrow),
                  iconSize: 64.0,
                  onPressed: player.play
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                color: Colors.white54,
                icon: const Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                color: Colors.white,
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero,
                    index: player.effectiveIndices!.first),
              );
            }
          },
        ),
        const Spacer(),
        IconButton(
          color: Colors.white38,
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Manifesto()));
          },
        ),
      ],
    );
  }
}

class Manifesto extends StatelessWidget {
  const Manifesto({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          height: double.infinity,
          color: Colors.black,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.0),
              color: const Color(0xff131313),
              borderRadius: BorderRadius.circular(12.0), // Rounded inner edges
            ),
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff131313),
                borderRadius: BorderRadius.circular(12.0), // Rounded inner edges
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Image.asset(
                            "assets/images/millicent_icon.png",
                            height: 150,
                            width: 150,
                          ),
                          const Text(
                                style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, height: 2, fontSize: 28),
                                textAlign: TextAlign.center,
                                "The 'millicent' Manifesto"
                          ),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "1) To view the existence of the internet as a positive opportunity towards the uniting of humanity."
                          ),
                          const Spacer(),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "2) To work towards the unity of humanity through the promotion of music, storytelling, poetry and sound design, from all languages and cultures."
                          ),
                          const Spacer(),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "3) To promote an existence beyond the barriers constructed through contemporary political notions of national borders, through the medium of radio."
                          ),
                          const Spacer(),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "4) To promote a sense of all humanity being equal. Regardless of age, race, gender, ethnicity or geographical location."
                          ),
                          const Spacer(),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "5) To respect and promote the further understanding of the importance of the co-existence of differing belief systems."
                          ),
                          const Spacer(),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "6) To broadcast, the very best audio quality content, celebrating the rich diversity of humanity’s cultural achievements, and to make this content available to all."
                          ),
                          const Spacer(),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "7) To consider cultural diversity a positive asset."
                          ),
                          const Spacer(),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "8) To educate, entertain and inform."
                          ),
                          const Spacer(),
                          const Text(
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 15),
                              textAlign: TextAlign.justify,
                              "9) To celebrate the contribution of the gift of creativity to humanity’s well being."
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF201F16),
                            foregroundColor: Colors.white54,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                              style: TextStyle(
                                  color: Colors.white54,
                                fontWeight: FontWeight.w100
                              ),
                              'back'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
