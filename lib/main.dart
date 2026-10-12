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

// documentRoot = 'assets/www' makes the bundled web build the server root, so the page's relative
// paths (../game/classes/...) resolve offline.
final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
  port: kServerPort,
  documentRoot: 'assets/www',
);

const String kInitialUrl = 'http://localhost:$kServerPort/web/index.html';

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
        // SafeArea keeps the square clear of the notch and the home indicator.
        body: SafeArea(
          // The game is square - board plus its score line - and lays itself out from the smaller
          // viewport dimension, so it gets a square of the available width, centred. The board then
          // fills that square exactly instead of sitting in the top half of a tall phone.
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(kInitialUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  // The high score is kept here, by the game.
                  domStorageEnabled: true,
                  // iOS is stricter than Android about audio without a gesture. Every sound in this
                  // game follows a tap, but this keeps the AudioContext from being created
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
      ),
    );
  }
}
