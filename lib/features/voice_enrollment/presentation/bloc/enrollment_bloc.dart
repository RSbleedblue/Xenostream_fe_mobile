import 'dart:async';
import 'dart:io';

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

    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(
      tempDir.path,
      'enrollment_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 24000,
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

    await _loadPlayback(path);
    emit(state.copyWith(phase: EnrollmentPhase.readyToSubmit));
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<void> _loadPlayback(String filePath) async {
    _cancelPlaybackSubscriptions();
    try {
      await _player.setFilePath(filePath);
    } catch (_) {
      return;
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
  }

  Future<void> _onPlaybackToggled(
    EnrollmentPlaybackToggled event,
    Emitter<EnrollmentState> emit,
  ) async {
    if (state.phase != EnrollmentPhase.readyToSubmit) return;

    if (state.isPlaying) {
      await _player.pause();
      emit(state.copyWith(isPlaying: false));
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
      emit(state.copyWith(isPlaying: true));
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

    await _stopPlayback();

    emit(
      state.copyWith(
        phase: EnrollmentPhase.submitting,
        clearError: true,
      ),
    );

    try {
      final profile = await _repository.enroll(
        localAudioPath: path,
        name: event.name,
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
