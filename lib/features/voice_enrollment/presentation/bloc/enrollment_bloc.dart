import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
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
  }

  final VoiceEnrollmentRepository _repository;
  final ActiveVoiceProfileStore _activeVoiceProfileStore;

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _elapsedTimer;
  DateTime? _recordingStartedAt;

  Future<void> _onStartRequested(
    EnrollmentStartRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    if (state.phase == EnrollmentPhase.recording ||
        state.phase == EnrollmentPhase.submitting) {
      return;
    }

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
      'enrollment_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
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
    } catch (_) {
      // ignore — still try to surface ready state if path exists
    }

    if (path == null || path.isEmpty) {
      emit(
        state.copyWith(
          phase: EnrollmentPhase.failure,
          errorMessage: 'Recording file was not available.',
        ),
      );
      return;
    }

    emit(state.copyWith(phase: EnrollmentPhase.readyToSubmit));
  }

  Future<void> _onSubmitRequested(
    EnrollmentSubmitRequested event,
    Emitter<EnrollmentState> emit,
  ) async {
    if (!state.canSubmit) return;

    final path = state.localRecordingPath;
    if (path == null) return;

    emit(
      state.copyWith(
        phase: EnrollmentPhase.submitting,
        clearError: true,
      ),
    );

    try {
      final profile = await _repository.enroll(localAudioPath: path);
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
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    emit(const EnrollmentState());
  }

  @override
  Future<void> close() async {
    _elapsedTimer?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    return super.close();
  }
}
