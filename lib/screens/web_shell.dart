import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/config.dart';

/// Renders the live DSA Mentor website in a full-screen WebView.
///
/// The app has no independently-built screens — it IS the website. Any
/// change shipped to [kWebUrl] (theme, icons, problems, new pages) shows up
/// here the next time the page loads, with no app rebuild required.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

enum _LoadState { loading, ready, error }

class _WebShellState extends State<WebShell> {
  late final WebViewController _controller;
  _LoadState _state = _LoadState.loading;
  double _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  WebViewController _buildController() {
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D0B08))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress / 100);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _state = _LoadState.loading;
              _errorMessage = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _state = _LoadState.ready);
          },
          onWebResourceError: (error) {
            // Only treat main-frame failures as fatal; a failed sub-resource
            // (an ad, an analytics ping) shouldn't blank the whole page.
            if (!error.isForMainFrame!) return;
            if (!mounted) return;
            setState(() {
              _state = _LoadState.error;
              _errorMessage = error.description;
            });
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            // Keep the site itself inside the app; hand mailto:/tel:/other
            // hosts off to the system so they open in Gmail, the dialer, etc.
            final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
            final isSameSite = uri.host == Uri.parse(kWebUrl).host;
            if (isHttp && isSameSite) return NavigationDecision.navigate;
            if (!isHttp) {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            }
            // External http(s) link (e.g. an OAuth provider) — let it load
            // in-app so a login redirect flow isn't interrupted.
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(kWebUrl));

    // Wire the system file picker to <input type="file"> on the page, e.g.
    // the resume upload in Settings.
    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      android.setOnShowFileSelector((params) async {
        final result = await FilePicker.platform.pickFiles();
        final path = result?.files.single.path;
        if (path == null) return [];
        return [Uri.file(path).toString()];
      });
    }

    return controller;
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  Future<void> _retry() async {
    setState(() {
      _state = _LoadState.loading;
      _errorMessage = null;
    });
    await _controller.loadRequest(Uri.parse(kWebUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _handleBack()) {
          if (mounted) SystemNavigatorExit.exit();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B08),
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_state == _LoadState.loading)
                LinearProgressIndicator(
                  value: _progress > 0 && _progress < 1 ? _progress : null,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: const Color(0xFFE9C88C),
                ),
              if (_state == _LoadState.error) _ErrorView(
                message: _errorMessage,
                onRetry: _retry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0B08),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFFE9C88C), size: 48),
          const SizedBox(height: 16),
          const Text(
            "Couldn't reach DSA Mentor",
            style: TextStyle(
              color: Color(0xFFF4ECDD),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFA99C85), fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE9C88C),
              foregroundColor: const Color(0xFF1A1409),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Tiny shim so this file doesn't need a direct `dart:io`/platform-channel
/// dependency just to close the app on Android back-from-root.
abstract final class SystemNavigatorExit {
  static void exit() {
    if (Platform.isAndroid) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }
}
