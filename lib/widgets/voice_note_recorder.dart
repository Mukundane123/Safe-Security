import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';

/// Records a short voice description to a file on the device. The recorded
/// path is reported back via [onRecorded] so the report can attach it.
class VoiceNoteRecorder extends StatefulWidget {
  final void Function(String? path) onRecorded;
  const VoiceNoteRecorder({super.key, required this.onRecorded});

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  String? _path;
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stop();
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}${Platform.pathSeparator}'
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recorder.start(const RecordConfig(), path: path).then((_) {
      if (!mounted) return;
      setState(() {
        _recording = true;
        _path = path;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _seconds++);
      });
    }).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start recording.')),
        );
      }
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _path = path ?? _path;
    });
    widget.onRecorded(_path);
  }

  Future<void> _play() async {
    final path = _path;
    if (path == null) return;
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasNote = _path != null;
    return Row(
      children: [
        IconButton.filled(
          onPressed: _toggleRecording,
          icon: Icon(_recording ? Icons.stop : Icons.mic),
          style: IconButton.styleFrom(
            backgroundColor:
                _recording ? AppColors.primary : AppColors.secondary,
          ),
          tooltip: _recording ? 'Stop recording' : 'Record voice note',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _recording
                    ? 'Recording... ${_fmt(_seconds)}'
                    : hasNote
                        ? 'Voice note attached'
                        : 'Attach a short voice description (optional)',
                style: TextStyle(
                  fontSize: 13,
                  color: _recording ? AppColors.primary : AppColors.muted,
                  fontWeight: _recording ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (hasNote && !_recording)
                Text(_fmt(_seconds), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        if (hasNote && !_recording)
          TextButton.icon(
            onPressed: _play,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Play'),
          ),
      ],
    );
  }
}