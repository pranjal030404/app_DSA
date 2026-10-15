import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Candidate tile for the interview room: an optional, local-only front-camera self-view.
/// Off until the candidate turns it on; nothing is recorded or uploaded. Permission problems and
/// missing cameras are explained, and the interview works without it.
class CameraSelfView extends StatefulWidget {
  const CameraSelfView({super.key, required this.statusLine, this.highlight = false, this.trailing});

  /// "Your turn", "Listening to you", ...
  final String statusLine;
  final bool highlight;
  final Widget? trailing;

  @override
  State<CameraSelfView> createState() => _CameraSelfViewState();
}

class _CameraSelfViewState extends State<CameraSelfView> {
  CameraController? _controller;
  String _state = 'off'; // off | requesting | on | denied | unavailable

  static const _messages = {
    'denied': 'Camera access was denied. Allow it in Android settings to see yourself. It is optional.',
    'unavailable': 'No camera is available. The interview works without it.',
  };

  Future<void> _start() async {
    setState(() => _state = 'requesting');
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _state = 'unavailable');
        return;
      }
      final front = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
      final controller = CameraController(front, ResolutionPreset.low, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _state = 'on';
      });
    } on CameraException catch (e) {
      if (mounted) setState(() => _state = e.code.contains('Denied') || e.code.contains('denied') ? 'denied' : 'unavailable');
    } catch (_) {
      if (mounted) setState(() => _state = 'unavailable');
    }
  }

  Future<void> _stop() async {
    final c = _controller;
    setState(() {
      _controller = null;
      _state = 'off';
    });
    await c?.dispose();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _state == 'on' && _controller != null && _controller!.value.isInitialized;
    return Semantics(
      label: 'You. ${on ? 'Camera on' : 'Camera off'}. ${widget.statusLine}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15181D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.highlight ? const Color(0xFF60A5FA) : const Color(0xFF2A2F37), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (on)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 480,
                        height: _controller!.value.previewSize?.width ?? 640,
                        child: CameraPreview(_controller!),
                      ),
                    )
                  else
                    const Center(child: CircleAvatar(radius: 28, backgroundColor: Color(0xFF232931), child: Icon(Icons.person_outline, color: Color(0xFFA3ACB9), size: 30))),
                  Positioned(
                    left: 10,
                    bottom: 8,
                    right: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('You', style: TextStyle(color: Color(0xFFECEFF3), fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(on ? widget.statusLine : 'Camera off · ${widget.statusLine}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFA3ACB9), fontSize: 11)),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.trailing != null) widget.trailing!,
                        IconButton.filledTonal(
                          tooltip: on ? 'Turn camera off' : 'Turn camera on',
                          onPressed: _state == 'requesting' ? null : (on ? _stop : _start),
                          icon: Icon(on ? Icons.videocam : Icons.videocam_off, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_messages[_state] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_messages[_state]!, style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
