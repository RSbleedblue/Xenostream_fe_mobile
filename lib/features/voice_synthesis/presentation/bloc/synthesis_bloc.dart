import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/session/active_voice_profile_store.dart';
import '../../data/voice_synthesis_repository.dart';
import 'synthesis_event.dart';
import 'synthesis_state.dart';

class SynthesisBloc extends Bloc<SynthesisEvent, SynthesisState> {
  SynthesisBloc({
    required VoiceSynthesisRepository repository,
    required ActiveVoiceProfileStore activeVoiceProfileStore,
    required AudioPlayer audioPlayer,
  })  : _repository = repository,
        _audioPlayer = audioPlayer,
        super(const SynthesisState()) {
    on<SynthesisTextChanged>(_onTextChanged);
    on<SynthesisVoiceSelected>(_onVoiceSelected);
    on<SynthesisVoiceCleared>(_onVoiceCleared);
    on<SynthesisGenerateRequested>(_onGenerateRequested);
    on<SynthesisPlayPauseToggled>(_onPlayPauseToggled);
    on<SynthesisPlaybackEnded>(_onPlaybackEnded);
    on<SynthesisResultCleared>(_onResultCleared);

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        add(const SynthesisPlaybackEnded());
      }
    });
  }

  final VoiceSynthesisRepository _repository;
  final AudioPlayer _audioPlayer;

  late final StreamSubscription<PlayerState> _playerStateSubscription;

  Future<void> _onTextChanged(
    SynthesisTextChanged event,
    Emitter<SynthesisState> emit,
  ) async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    }
    await _audioPlayer.stop();

    final hadResult = state.result != null;
    emit(
      state.copyWith(
        text: event.text,
        clearResult: hadResult,
        phase: hadResult ? SynthesisPhase.idle : state.phase,
        clearError: true,
      ),
    );
  }

  void _onVoiceSelected(
    SynthesisVoiceSelected event,
    Emitter<SynthesisState> emit,
  ) {
    emit(state.copyWith(selectedVoiceId: event.voiceId, clearError: true));
  }

  void _onVoiceCleared(
    SynthesisVoiceCleared event,
    Emitter<SynthesisState> emit,
  ) {
    emit(state.copyWith(clearVoiceId: true, clearError: true));
  }

  Future<void> _onGenerateRequested(
    SynthesisGenerateRequested event,
    Emitter<SynthesisState> emit,
  ) async {
    if (!state.canGenerate) return;

    final voiceId = state.selectedVoiceId;
    if (voiceId == null) {
      emit(
        state.copyWith(
          phase: SynthesisPhase.failure,
          errorMessage: 'Select a voice before synthesizing.',
          clearResult: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        phase: SynthesisPhase.generating,
        clearError: true,
        clearResult: true,
      ),
    );

    try {
      await _audioPlayer.stop();
      final result = await _repository.synthesize(
        voiceProfileId: voiceId,
        text: state.text.trim(),
      );
      if (result.audioFilePath != null) {
        await _audioPlayer.setFilePath(result.audioFilePath!);
      } else if (result.audioAssetPath != null) {
        await _audioPlayer.setAsset(result.audioAssetPath!);
      } else {
        throw StateError('SynthesisResult has no playable source');
      }
      emit(
        state.copyWith(
          phase: SynthesisPhase.ready,
          result: result,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          phase: SynthesisPhase.failure,
          errorMessage: 'Synthesis failed: $e',
          clearResult: true,
        ),
      );
    }
  }

  Future<void> _onPlayPauseToggled(
    SynthesisPlayPauseToggled event,
    Emitter<SynthesisState> emit,
  ) async {
    if (state.result == null) return;

    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      emit(state.copyWith(phase: SynthesisPhase.ready));
      return;
    }

    if (state.phase == SynthesisPhase.ready ||
        state.phase == SynthesisPhase.playing ||
        state.phase == SynthesisPhase.failure) {
      try {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        emit(state.copyWith(phase: SynthesisPhase.playing, clearError: true));
      } catch (e) {
        emit(
          state.copyWith(
            phase: SynthesisPhase.failure,
            errorMessage: 'Playback failed: $e',
          ),
        );
      }
    }
  }

  void _onPlaybackEnded(
    SynthesisPlaybackEnded event,
    Emitter<SynthesisState> emit,
  ) {
    if (state.result == null) return;
    emit(state.copyWith(phase: SynthesisPhase.ready));
  }

  Future<void> _onResultCleared(
    SynthesisResultCleared event,
    Emitter<SynthesisState> emit,
  ) async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    }
    await _audioPlayer.stop();
    emit(state.copyWith(phase: SynthesisPhase.idle, clearResult: true, clearError: true));
  }

  @override
  Future<void> close() async {
    await _playerStateSubscription.cancel();
    await _audioPlayer.dispose();
    return super.close();
  }
}
