import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// A fixed port matters: localStorage is keyed by origin, so a random port would move the origin on
// every launch and silently reset the high score. A loopback server is used at all (rather than a
// file:// document) because a file:// page has no durable storage.
const int kServerPort = 8090;

// The game's own ground colour, so nothing flashes between the launch screen and the board.
const Color kBoardColour = Color(0xFF221100);

// The game's own ink, and a dimmer tone for the second line of the header.
const Color kInk = Color(0xFFFFEECC);
const Color kInkDim = Color(0xFFB9A489);

// The turns run cream, amber when short, red when nearly gone, over a dark track - the same three
// tones the game draws and the Android header uses. Against the board they measure 15.98:1, 10.16:1
// and 7.13:1, all clear of the 4.5:1 that body text is held to.
const Color kTurnMid = Color(0xFFF0B84A);
const Color kTurnLow = Color(0xFFFF7A5C);
const Color kTurnTrack = Color(0xFF33200D);

// documentRoot = 'assets/www' makes the bundled web build the server root, so the page's relative
// paths (../game/classes/...) resolve offline.
final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
  port: kServerPort,
  documentRoot: 'assets/www',
);

// hud=off: the game keeps no room for a score line of its own, and the board takes the whole square
// while the header below draws the numbers as real text.
const String kInitialUrl =
    'http://localhost:$kServerPort/web/index.html?hud=off';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The server has to be up before the WebView asks for anything.
  await _localhostServer.start();
  runApp(const TextCrushApp());
}

class TextCrushApp extends StatelessWidget {
  const TextCrushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Crush',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true)
          .copyWith(scaffoldBackgroundColor: kBoardColour),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  InAppWebViewController? _controller;

  int _score = 0;
  int _turns = 20;
  int _best = 0;
  bool _muted = false;

  /// The turns a game starts with, reported by the game so the bar's fraction is not a guess.
  int _total = 20;

  /// True for one beat after a turn is spent, which is what makes the counter swell.
  bool _pulse = false;
  Timer? _pulseTimer;

  /// False until the first state report of this app run, so the first one does not pulse.
  bool _reported = false;

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final controller = _controller;

        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }

        // One page, so there is nothing to go back to: leave the app.
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: kBoardColour,
        // SafeArea keeps both the header and the square clear of the notch and the home indicator.
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              // The game is square - the board, with the score line left to this header - and lays
              // itself out from the smaller viewport dimension, so it gets a square, centred.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(kInitialUrl)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        // The high score is kept here, by the game.
                        domStorageEnabled: true,
                        // iOS is stricter than Android about audio without a gesture. Every sound in
                        // this game follows a tap, but this keeps the AudioContext from being created
                        // suspended while the page loads.
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        // No zoom, no long-press menu, no overscroll: it should feel like an app.
                        supportZoom: false,
                        disableContextMenu: true,
                        disallowOverScroll: true,
                        transparentBackground: false,
                        // Safari's devtools, debug builds only - never in the shipped app.
                        isInspectable: kDebugMode,
                      ),
                      shouldOverrideUrlLoading: (controller, action) async {
                        final uri = action.request.url;

                        // The game never navigates anywhere; keep it that way.
                        if (uri != null && uri.host == 'localhost') {
                          return NavigationActionPolicy.ALLOW;
                        }

                        return NavigationActionPolicy.CANCEL;
                      },
                      onWebViewCreated: (controller) {
                        _controller = controller;

                        // A tap should be felt: the page calls this when a run is cleared.
                        controller.addJavaScriptHandler(
                          handlerName: 'haptic',
                          callback: (args) {
                            HapticFeedback.mediumImpact();
                            return true;
                          },
                        );

                        // The page reports {score, turns, best, muted} after every move and at the
                        // end, so this header never has to read numbers out of a canvas.
                        controller.addJavaScriptHandler(
                          handlerName: 'state',
                          callback: (args) {
                            final payload = args.isNotEmpty ? args.first : null;

                            if (payload is Map) {
                              final turns =
                                  (payload['turns'] as num?)?.toInt() ?? _turns;
                              final wasTurns = _turns;
                              final firstReport = !_reported;

                              _reported = true;

                              setState(() {
                                _score =
                                    (payload['score'] as num?)?.toInt() ??
                                    _score;
                                _turns = turns;
                                _best =
                                    (payload['best'] as num?)?.toInt() ?? _best;
                                _muted = payload['muted'] == true;
                                _total =
                                    (payload['total'] as num?)?.toInt() ?? _total;
                              });

                              // A spent turn is worth a beat; the first report of a game is not.
                              if (!firstReport && wasTurns != turns) {
                                _pulseTimer?.cancel();

                                setState(() => _pulse = true);

                                _pulseTimer = Timer(
                                  const Duration(milliseconds: 90),
                                  () {
                                    if (mounted) {
                                      setState(() => _pulse = false);
                                    }
                                  },
                                );
                              }
                            }

                            return true;
                          },
                        );
                      },
                      onReceivedError: (controller, request, error) {
                        debugPrint(
                          '[webview] ${error.description} for ${request.url}',
                        );
                      },
                      onConsoleMessage: (controller, message) {
                        debugPrint('[webview] ${message.message}');
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Score, turns, best, the rules and the sound button as real Flutter text, plus the turn bar.
  ///
  /// The game draws its own score line for the browser; on a phone that text was the weakest thing on
  /// screen - 11 dp tall, rasterised at 1x, and a fill colour that measured 1.45:1 against the board.
  /// Real text is crisp at the screen's density, scales with the system font setting, and a screen
  /// reader can read it. The score eases to its new value instead of jumping, and the turns run cream
  /// then amber then red as the game goes on, with a bar under the whole header to back it up.
  Widget _header() {
    final int left = _turns < 0 ? 0 : (_turns > _total ? _total : _turns);
    final int right = _total - left;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 4, 2),
          child: Row(
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: _score),
                duration: const Duration(milliseconds: 250),
                builder: (context, value, child) => Text(
                  '$value',
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Swelling the counter is easier to notice than a number quietly changing.
                  AnimatedScale(
                    scale: _pulse ? 1.22 : 1.0,
                    duration: const Duration(milliseconds: 90),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$_turns ${_turns == 1 ? "turn" : "turns"}',
                      style: TextStyle(color: _turnsInk(), fontSize: 15),
                    ),
                  ),
                  Text(
                    'best $_best',
                    style: const TextStyle(color: kInkDim, fontSize: 15),
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Nothing on screen said what to do; the game can always explain itself.
                  _controller?.evaluateJavascript(
                    source: 'window.setTextCrushHelp(true)',
                  );
                },
                child: const Text(
                  '?',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // The web build owns the flag; it reports the new value straight back.
                  _controller?.evaluateJavascript(
                    source: 'window.setTextCrushMuted(${!_muted})',
                  );
                },
                child: Text(
                  _muted ? 'Sound off' : 'Sound on',
                  style: const TextStyle(color: kInk, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        // The bar is the header's full width, so the turns read as a fraction of the game at a glance.
        SizedBox(
          height: 3,
          child: Row(
            children: [
              Expanded(
                flex: left,
                child: ColoredBox(color: _turnsInk()),
              ),
              Expanded(
                flex: right,
                child: const ColoredBox(color: kTurnTrack),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The turns' ink: cream while there is time, amber when it is short, red when it is nearly gone.
  ///
  /// The three measure 15.98:1, 10.16:1 and 7.13:1 against the board, all clear of the 4.5:1 that
  /// body text is held to.
  Color _turnsInk() {
    if (_turns <= 2) {
      return kTurnLow;
    }

    if (_turns <= 5) {
      return kTurnMid;
    }

    return kInk;
  }
}
