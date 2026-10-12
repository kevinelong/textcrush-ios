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
                              setState(() {
                                _score =
                                    (payload['score'] as num?)?.toInt() ??
                                    _score;
                                _turns =
                                    (payload['turns'] as num?)?.toInt() ??
                                    _turns;
                                _best =
                                    (payload['best'] as num?)?.toInt() ?? _best;
                                _muted = payload['muted'] == true;
                              });
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

  /// Score, turns, best and the sound button as real Flutter text.
  ///
  /// The game draws its own score line for the browser; on a phone that text was the weakest thing on
  /// screen - 11 dp tall, rasterised at 1x, and a fill colour that measured 1.45:1 against the board.
  /// Real text is crisp at the screen's density, scales with the system font setting, and a screen
  /// reader can read it.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 10, 4),
      child: Row(
        children: [
          Text(
            '$_score',
            style: const TextStyle(
              color: kInk,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_turns ${_turns == 1 ? "turn" : "turns"}',
                style: const TextStyle(color: kInkDim, fontSize: 15),
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
    );
  }
}
