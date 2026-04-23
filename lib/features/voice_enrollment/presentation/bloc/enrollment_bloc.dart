import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../../core/constants/recording_constants.dart';
import '../../../../core/session/active_voice_profile_store.dart';
import '../../data/voice_enrollment_repository.dart';
import 'enrollment_event.dart';
import 'enrollment_state.dart';

class EnrollmentBloc extends Bloc<EnrollmentEvent, EnrollmentState> {
  EnrollmentBloc({
    required VoiceEnrollmentRepository repository,
    required ActiveVoiceProfileStore activeVoiceProfileStore,
  })  : _repository = repository,
        _activeVoiceProfileStore = activeVoiceProfileStore,
        super(const EnrollmentState()) {
    on<EnrollmentStartRequested>(_onStartRequested);
    on<EnrollmentStopRequested>(_onStopRequested);
    on<EnrollmentAutoStopRequested>(_onAutoStopRequested);
    on<EnrollmentElapsedUpdated>(_onElapsedUpdated);
    on<EnrollmentSubmitRequested>(_onSubmitRequested);
    on<EnrollmentResetRequested>(_onResetRequested);
    on<EnrollmentPlaybackToggled>(_onPlaybackToggled);
    on<EnrollmentPlaybackPositionChanged>(_onPlaybackPositionChanged);
    on<EnrollmentPlaybackDurationChanged>(_onPlaybackDurationChanged);
    on<EnrollmentPlaybackCompleted>(_onPlaybackCompleted);
    on<EnrollmentPlaybackSeekRequested>(_onPlaybackSeekRequested);
    on<EnrollmentDeleteRecordingRequested>(_onDeleteRecordingRequested);
  }

  final VoiceEnrollmentRepository _repository;
  final ActiveVoiceProfileStore _activeVoiceProfileStore;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _elapsedTimer;
  DateTime? _recordingStartedAt;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  Future<void> _onStartRequested(
    EnrollmentStartRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    if (state.phase == EnrollmentPhase.recording ||
        state.phase == EnrollmentPhase.submitting) {
      return;
    }

    await _stopPlayback();

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      emit(
        state.copyWith(
          phase: EnrollmentPhase.failure,
          errorMessage: 'Microphone permission is required to record.',
          clearRecordingPath: true,
        ),
      );
      return;
    }

    await _configureForRecording();

    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(
      tempDir.path,
      'enrollment_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          // 44.1kHz is better supported by platform decoders than 24kHz in some cases.
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          noiseSuppress: true,
          echoCancel: true,
        ),
        path: filePath,
      );
    } catch (e) {
      emit(
        state.copyWith(
          phase: EnrollmentPhase.failure,
          errorMessage: 'Could not start recording: $e',
          clearRecordingPath: true,
        ),
      );
      return;
    }

    _recordingStartedAt = DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final start = _recordingStartedAt;
      if (start == null) return;
      final elapsed = DateTime.now().difference(start);
      if (elapsed >= kEnrollmentMaxDuration) {
        add(const EnrollmentAutoStopRequested());
      } else {
        add(EnrollmentElapsedUpdated(elapsed));
      }
    });

    emit(
      state.copyWith(
        phase: EnrollmentPhase.recording,
        elapsed: Duration.zero,
        localRecordingPath: filePath,
        isPlaying: false,
        playbackPosition: Duration.zero,
        playbackDuration: Duration.zero,
        clearError: true,
        clearProfile: true,
        clearPreviewError: true,
      ),
    );
  }

  void _onElapsedUpdated(
    EnrollmentElapsedUpdated event,
    Emitter<EnrollmentState> emit,
  ) {
    if (state.phase != EnrollmentPhase.recording) return;
    emit(state.copyWith(elapsed: event.elapsed));
  }

  Future<void> _onStopRequested(
    EnrollmentStopRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    await _finishRecording(emit);
  }

  Future<void> _onAutoStopRequested(
    EnrollmentAutoStopRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    await _finishRecording(emit);
  }

  Future<void> _finishRecording(Emitter<EnrollmentState> emit) async {
    if (state.phase != EnrollmentPhase.recording) return;

    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _recordingStartedAt = null;

    final path = state.localRecordingPath;
    try {
      await _recorder.stop();
    } catch (_) {}

    if (path == null || path.isEmpty) {
      emit(
        state.copyWith(
          phase: EnrollmentPhase.failure,
          errorMessage: 'Recording file was not available.',
        ),
      );
      return;
    }

    if (!kIsWeb) {
      // Let the file finish finalizing, then switch the session to playback
      // so preview routes to the loudspeaker (not the in-call earpiece on Android).
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    final loadError = await _loadPlayback(path);
    emit(
      state.copyWith(
        phase: EnrollmentPhase.readyToSubmit,
        isPlaying: false,
        clearPreviewError: loadError == null,
        previewError: loadError,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<String?> _loadPlayback(String filePath) async {
    _cancelPlaybackSubscriptions();
    final file = File(filePath);
    try {
      if (!kIsWeb) {
        if (!await file.exists()) {
          return 'Recording file was not found.';
        }
        if (await file.length() < 200) {
          return 'Recording is too short. Record a few words and try again.';
        }
      }
    } catch (e) {
      return 'Could not access the recording: $e';
    }

    try {
      if (kIsWeb) {
        return 'Local preview is not available on this platform.';
      }
      // Critical for output routing: `voiceCommunication` / record-only would keep
      // the phone on the in-call/earpiece path, which is easy to "not hear" at all.
      await _configureForPreviewPlayback();
      try {
        await _player.setFilePath(filePath);
      } catch (e) {
        await _player.setUrl(Uri.file(filePath, windows: false).toString());
      }
      try {
        await _player.setVolume(1.0);
      } catch (_) {}
    } catch (e) {
      return 'Could not open recording for preview: $e';
    }

    _positionSub = _player.positionStream.listen((pos) {
      add(EnrollmentPlaybackPositionChanged(pos));
    });
    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) add(EnrollmentPlaybackDurationChanged(dur));
    });
    _playerStateSub = _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        add(const EnrollmentPlaybackCompleted());
      }
    });
    return null;
  }

  /// Session while the mic is open: capture + (optional) local monitoring.
  Future<void> _configureForRecording() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
        ),
      );
      await session.setActive(true);
    } catch (_) {
      // If configuration fails, recording/playback may still work on some devices.
    }
  }

  /// Session for preview: **playback** (not in-call) so the speaker/headphones get music/media routing.
  Future<void> _configureForPreviewPlayback() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          // `media` routes to speaker; `voiceCommunication` is often the earpiece.
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
        ),
      );
      await session.setActive(true);
    } catch (_) {
      // If configuration fails, try playback anyway.
    }
  }

  Future<void> _onPlaybackToggled(
    EnrollmentPlaybackToggled event,
    Emitter<EnrollmentState> emit,
  ) async {
    if (state.phase != EnrollmentPhase.readyToSubmit) return;

    if (state.isPlaying) {
      await _player.pause();
      emit(state.copyWith(isPlaying: false));
      return;
    }

    if (state.previewError != null) return;

    try {
      await _configureForPreviewPlayback();
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.setVolume(1.0);
      await _player.play();
      emit(state.copyWith(isPlaying: true));
    } catch (e) {
      emit(
        state.copyWith(
          isPlaying: false,
          previewError: 'Playback failed: $e',
        ),
      );
    }
  }

  void _onPlaybackPositionChanged(
    EnrollmentPlaybackPositionChanged event,
    Emitter<EnrollmentState> emit,
  ) {
    emit(state.copyWith(playbackPosition: event.position));
  }

  void _onPlaybackDurationChanged(
    EnrollmentPlaybackDurationChanged event,
    Emitter<EnrollmentState> emit,
  ) {
    emit(state.copyWith(playbackDuration: event.duration));
  }

  Future<void> _onPlaybackCompleted(
    EnrollmentPlaybackCompleted event,
    Emitter<EnrollmentState> emit,
  ) async {
    emit(state.copyWith(isPlaying: false));
  }

  Future<void> _onPlaybackSeekRequested(
    EnrollmentPlaybackSeekRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    await _player.seek(event.position);
  }

  Future<void> _stopPlayback() async {
    _cancelPlaybackSubscriptions();
    try {
      await _player.stop();
    } catch (_) {}
  }

  void _cancelPlaybackSubscriptions() {
    _positionSub?.cancel();
    _positionSub = null;
    _durationSub?.cancel();
    _durationSub = null;
    _playerStateSub?.cancel();
    _playerStateSub = null;
  }

  // ---------------------------------------------------------------------------
  // Delete recording
  // ---------------------------------------------------------------------------

  Future<void> _onDeleteRecordingRequested(
    EnrollmentDeleteRecordingRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    await _stopPlayback();
    final path = state.localRecordingPath;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    emit(const EnrollmentState());
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _onSubmitRequested(
    EnrollmentSubmitRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    if (!state.canSubmit) return;

    final path = state.localRecordingPath;
    if (path == null) return;

    final display = event.displayName.trim();
    if (display.isEmpty) return;

    await _stopPlayback();

    emit(
      state.copyWith(
        phase: EnrollmentPhase.submitting,
        clearError: true,
      ),
    );

    String? o(String? s) {
      if (s == null) return null;
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    try {
      final profile = await _repository.enroll(
        localAudioPath: path,
        displayName: display,
        details: o(event.details),
        tags: o(event.tags),
        metadata: o(event.metadata),
      );
      _activeVoiceProfileStore.setProfile(profile);
      emit(
        state.copyWith(
          phase: EnrollmentPhase.success,
          profile: profile,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          phase: EnrollmentPhase.failure,
          errorMessage: 'Enrollment failed: $e',
        ),
      );
    }
  }

  Future<void> _onResetRequested(
    EnrollmentResetRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _recordingStartedAt = null;
    await _stopPlayback();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    emit(const EnrollmentState());
  }

  @override
  Future<void> close() async {
    _elapsedTimer?.cancel();
    _cancelPlaybackSubscriptions();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    await _player.dispose();
    return super.close();
  }
}
