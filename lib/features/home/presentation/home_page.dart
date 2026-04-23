import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/xenostream_api_client.dart';
import '../../../core/session/active_voice_profile_store.dart';
import '../../voice_synthesis/data/voice_synthesis_repository.dart';
import '../../voice_synthesis/presentation/bloc/synthesis_bloc.dart';
import '../../voice_synthesis/presentation/bloc/synthesis_event.dart';
import '../../voice_synthesis/presentation/bloc/synthesis_state.dart';

const String kHomeVoicePreviewText =
    "Here's a short sample of this cloned voice.";

/// Figma-aligned home: feature hero, voice carousel, and quick synthesis.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final TextEditingController _scriptController = TextEditingController();

  List<VoiceUploadResult> _apiVoices = [];
  bool _voicesLoading = true;
  late final ActiveVoiceProfileStore _profileStore;

  final AudioPlayer _homePreviewPlayer = AudioPlayer();
  StreamSubscription<bool>? _homePreviewPlayingSub;
  String? _loadedHomePreviewVoiceId;
  String? _homeTtsLoadVoiceId;

  @override
  void initState() {
    super.initState();
    _profileStore = context.read<ActiveVoiceProfileStore>();
    WidgetsBinding.instance.addObserver(this);
    _homePreviewPlayingSub = _homePreviewPlayer.playingStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _fetchVoices();
    _profileStore.addListener(_onProfileChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = context.read<SynthesisBloc>().state.text;
      if (t.isNotEmpty) {
        _scriptController.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchVoices();
  }

  void _onProfileChanged() {
    _fetchVoices();
    final profile = _profileStore.profile;
    if (profile != null) {
      context.read<SynthesisBloc>().add(SynthesisVoiceSelected(profile.id));
    }
  }

  Future<void> _fetchVoices() async {
    try {
      final client = context.read<XenoStreamApiClient>();
      final voices = await client.listVoices();
      if (!mounted) return;
      setState(() {
        _apiVoices = voices;
        _voicesLoading = false;
      });
      final rid = _loadedHomePreviewVoiceId;
      if (rid != null && !voices.any((e) => e.voiceId == rid)) {
        unawaited(_stopHomePreviewPlayback());
      }
      final bloc = context.read<SynthesisBloc>();
      if (voices.isNotEmpty && bloc.state.selectedVoiceId == null) {
        _selectVoice(voices.first);
      } else if (voices.isEmpty) {
        final profile = _profileStore.profile;
        if (profile != null) {
          bloc.add(SynthesisVoiceSelected(profile.id));
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _voicesLoading = false);
    }
  }

  void _selectVoice(VoiceUploadResult voice) {
    context.read<SynthesisBloc>().add(SynthesisVoiceSelected(voice.voiceId));
  }

  /// Primary label: server [VoiceUploadResult.displayName], else file stem / [voiceId].
  static String _displayName(VoiceUploadResult v) {
    final name = v.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    if (v.filePath.isNotEmpty) {
      final segs = v.filePath.split(RegExp(r'[\\/]'));
      final filename = segs.isNotEmpty ? segs.last : v.filePath;
      final dotIndex = filename.lastIndexOf('.');
      final stem = dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
      if (stem.length <= 12) {
        return stem;
      }
    }
    if (v.voiceId.length <= 12) {
      return v.voiceId;
    }
    return '${v.voiceId.substring(0, 8)}…';
  }

  /// Secondary line: [details] from API, else [voiceId].
  static String _subtitleFor(VoiceUploadResult v) {
    final d = v.details?.trim();
    if (d != null && d.isNotEmpty) {
      return d;
    }
    return v.voiceId;
  }

  /// Label for Quick Synthesis / target row — uses API [displayName] from [_apiVoices] when available.
  String _labelForSelectedId(String? selectedId) {
    if (selectedId == null) {
      return 'Select a voice';
    }
    for (final v in _apiVoices) {
      if (v.voiceId == selectedId) {
        return _displayName(v);
      }
    }
    final p = _profileStore.profile;
    if (p != null && p.id == selectedId) {
      return p.displayName;
    }
    return selectedId.length > 8 ? '${selectedId.substring(0, 8)}…' : selectedId;
  }

  Future<void> _configureSessionForHomePreview() async {
    if (kIsWeb) {
      return;
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
        ),
      );
      await session.setActive(true);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _stopHomePreviewPlayback() async {
    _homeTtsLoadVoiceId = null;
    _loadedHomePreviewVoiceId = null;
    try {
      if (_homePreviewPlayer.playing) {
        await _homePreviewPlayer.pause();
      }
      await _homePreviewPlayer.stop();
    } catch (_) {
      // ignore
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleHomeVoicePreview(VoiceUploadResult v) async {
    if (_homeTtsRequestInAir) {
      return;
    }
    final id = v.voiceId;
    if (_loadedHomePreviewVoiceId == id) {
      if (_homePreviewPlayer.playing) {
        await _homePreviewPlayer.pause();
        return;
      }
      await _configureSessionForHomePreview();
      if (_homePreviewPlayer.processingState == ProcessingState.completed) {
        await _homePreviewPlayer.seek(Duration.zero);
      }
      try {
        await _homePreviewPlayer.setVolume(1.0);
        await _homePreviewPlayer.play();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
        }
      }
      return;
    }
    setState(() {
      _homeTtsLoadVoiceId = id;
    });
    try {
      await _configureSessionForHomePreview();
      try {
        await _homePreviewPlayer.stop();
      } catch (_) {
        // ignore
      }
      if (!mounted) {
        return;
      }
      final result = await context.read<VoiceSynthesisRepository>().synthesize(
            voiceProfileId: id,
            text: kHomeVoicePreviewText,
          );
      if (result.audioFilePath == null) {
        throw StateError('Synthesis did not return a file');
      }
      if (!mounted) {
        return;
      }
      await _homePreviewPlayer.setFilePath(result.audioFilePath!);
      try {
        await _homePreviewPlayer.setVolume(1.0);
      } catch (_) {
        // ignore
      }
      await _homePreviewPlayer.play();
      _loadedHomePreviewVoiceId = id;
    } catch (e) {
      if (mounted) {
        _loadedHomePreviewVoiceId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't play preview: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _homeTtsLoadVoiceId = null;
        });
      }
    }
  }

  bool get _homeTtsRequestInAir => _homeTtsLoadVoiceId != null;

  @override
  void dispose() {
    unawaited(_homePreviewPlayingSub?.cancel());
    unawaited(_homePreviewPlayer.dispose());
    _profileStore.removeListener(_onProfileChanged);
    WidgetsBinding.instance.removeObserver(this);
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetVoice(BuildContext context) async {
    final choice = await showModalBottomSheet<VoiceUploadResult>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final v in _apiVoices)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: TertiaryPalette.t100,
                    child: Icon(Icons.graphic_eq_rounded, color: TertiaryPalette.t600),
                  ),
                  title: Text(_displayName(v)),
                  subtitle: Text(
                    _subtitleFor(v),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.pop(ctx, v),
                ),
              if (_apiVoices.isEmpty)
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('No voices available'),
                  subtitle: Text('Record or upload a voice first.'),
                ),
            ],
          ),
        );
      },
    );
    if (choice != null && mounted) {
      _selectVoice(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final synthesisState = context.watch<SynthesisBloc>().state;

    return BlocListener<SynthesisBloc, SynthesisState>(
      listenWhen: (SynthesisState a, SynthesisState b) => a.text != b.text,
      listener: (BuildContext context, SynthesisState state) {
        if (_scriptController.text == state.text) return;
        _scriptController.value = TextEditingValue(
          text: state.text,
          selection: TextSelection.collapsed(
            offset: state.text.length.clamp(0, state.text.length),
          ),
        );
      },
      child: BlocListener<SynthesisBloc, SynthesisState>(
        listenWhen: (SynthesisState a, SynthesisState b) =>
            a.phase != b.phase && b.phase == SynthesisPhase.failure,
        listener: (BuildContext context, SynthesisState state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverList.list(
                children: [
                  _FeatureHeroCard(onStartRecording: () => context.go('/record')),
                  const SizedBox(height: 28),
                  _SectionTitleRow(
                    title: 'Active Voice Clones',
                    actionLabel: 'View Library →',
                    onAction: () => context.go('/library'),
                  ),
                  const SizedBox(height: 12),
                  _VoiceCarousel(
                    voices: _apiVoices,
                    selectedVoiceId: synthesisState.selectedVoiceId,
                    loading: _voicesLoading,
                    onRefresh: _fetchVoices,
                    onSelect: _selectVoice,
                    onPreviewVoice: _toggleHomeVoicePreview,
                    ttsLoadVoiceId: _homeTtsLoadVoiceId,
                    loadedPreviewVoiceId: _loadedHomePreviewVoiceId,
                    isPreviewPlayerPlaying: _homePreviewPlayer.playing,
                    onBeforeDelete: (VoiceUploadResult v) {
                      if (v.voiceId == _loadedHomePreviewVoiceId ||
                          v.voiceId == _homeTtsLoadVoiceId) {
                        unawaited(_stopHomePreviewPlayback());
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Quick Synthesis',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickSynthesisCard(
                    scriptController: _scriptController,
                    targetLabel: _labelForSelectedId(
                      synthesisState.selectedVoiceId,
                    ),
                    onPickVoice: () => _pickTargetVoice(context),
                    onScriptChanged: (String v) =>
                        context.read<SynthesisBloc>().add(SynthesisTextChanged(v)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureHeroCard extends StatelessWidget {
  const _FeatureHeroCard({required this.onStartRecording});

  final VoidCallback onStartRecording;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const radius = 28.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TertiaryPalette.t500,
                  PrimaryPalette.p600,
                  PrimaryPalette.p800,
                ],
              ),
            ),
            child: const SizedBox(width: double.infinity, height: 280),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -8,
            bottom: -24,
            child: Icon(
              Icons.record_voice_over_rounded,
              size: 168,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white.withValues(alpha: 0.95)),
                        const SizedBox(width: 8),
                        Text(
                          'How to use it',
                          style: textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Capture New\nResonance',
                  style: textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Clone any voice with just 30 seconds of audio. Our highest fidelity model yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: SecondaryPalette.s800,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onStartRecording,
                    icon: const Icon(Icons.mic_rounded, size: 22),
                    label: Text(
                      'Start Recording',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SecondaryPalette.s800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceCarousel extends StatelessWidget {
  const _VoiceCarousel({
    required this.voices,
    required this.selectedVoiceId,
    required this.loading,
    required this.onRefresh,
    required this.onSelect,
    required this.onPreviewVoice,
    required this.ttsLoadVoiceId,
    required this.loadedPreviewVoiceId,
    required this.isPreviewPlayerPlaying,
    this.onBeforeDelete,
  });

  final List<VoiceUploadResult> voices;
  final String? selectedVoiceId;
  final bool loading;
  final VoidCallback onRefresh;
  final ValueChanged<VoiceUploadResult> onSelect;
  final Future<void> Function(VoiceUploadResult v) onPreviewVoice;
  final String? ttsLoadVoiceId;
  final String? loadedPreviewVoiceId;
  final bool isPreviewPlayerPlaying;
  final void Function(VoiceUploadResult v)? onBeforeDelete;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 152,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (voices.isEmpty) {
      return SizedBox(
        height: 152,
        child: Center(
          child: Text(
            'No voices yet — record or upload one to get started.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: voices.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int i) {
          final v = voices[i];
          final isSelected = v.voiceId == selectedVoiceId;
          final isThisPreviewPlaying =
              loadedPreviewVoiceId == v.voiceId && isPreviewPlayerPlaying;
          final isThisPreviewLoading = ttsLoadVoiceId == v.voiceId;
          return GestureDetector(
            onTap: () => onSelect(v),
            child: _VoiceCloneCard(
              name: _HomePageState._displayName(v),
              subtitle: _HomePageState._subtitleFor(v),
              badge: isSelected ? 'SELECTED' : 'VOICE',
              highlight: isSelected,
              onDelete: () => _confirmDeleteVoice(
                context,
                v,
                onBeforeDelete: onBeforeDelete,
              ),
              onPreview: () {
                unawaited(onPreviewVoice(v));
              },
              previewLoading: isThisPreviewLoading,
              isPreviewPlaying: isThisPreviewPlaying,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteVoice(
    BuildContext context,
    VoiceUploadResult voice, {
    void Function(VoiceUploadResult v)? onBeforeDelete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete voice?'),
        content: const Text(
          'This will permanently remove the voice profile from the server. You can always record a new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    onBeforeDelete?.call(voice);
    if (!context.mounted) {
      return;
    }

    try {
      final client = context.read<XenoStreamApiClient>();
      await client.deleteVoice(voice.voiceId);
      if (!context.mounted) return;
      onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice deleted.')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}

class _VoiceCloneCard extends StatelessWidget {
  const _VoiceCloneCard({
    required this.name,
    required this.subtitle,
    required this.badge,
    required this.highlight,
    this.onDelete,
    this.onPreview,
    this.previewLoading = false,
    this.isPreviewPlaying = false,
  });

  final String name;
  final String subtitle;
  final String badge;
  final bool highlight;
  final VoidCallback? onDelete;
  final VoidCallback? onPreview;
  final bool previewLoading;
  final bool isPreviewPlaying;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 268,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadii.lgBorder,
          border: Border.all(
            color: highlight
                ? AppColors.primaryPurple.withValues(alpha: 0.35)
                : NeutralPalette.n200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onPreview != null) ...[
                    Semantics(
                      label: isPreviewPlaying ? 'Pause sample' : 'Hear a sample',
                      child: Material(
                        color: AppColors.chipBackground,
                        borderRadius: AppRadii.smBorder,
                        child: InkWell(
                          onTap: onPreview,
                          borderRadius: AppRadii.smBorder,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: previewLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isPreviewPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: AppColors.primaryPurple,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: AppRadii.smBorder,
                    ),
                    child: const Icon(Icons.mic_rounded, color: AppColors.primaryPurple),
                  ),
                  const Spacer(),
                  if (onDelete != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 18),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdBorder),
                        onSelected: (value) {
                          if (value == 'delete') onDelete!();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                SizedBox(width: 10),
                                Text('Delete voice', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (onDelete == null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: TertiaryPalette.t100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          badge,
                          style: textTheme.labelSmall?.copyWith(
                            color: TertiaryPalette.t700,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Container(
                      width: 3,
                      height: 6.0 + (i * 3.0),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.35 + i * 0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSynthesisCard extends StatelessWidget {
  const _QuickSynthesisCard({
    required this.scriptController,
    required this.targetLabel,
    required this.onPickVoice,
    required this.onScriptChanged,
  });

  final TextEditingController scriptController;
  final String targetLabel;
  final VoidCallback onPickVoice;
  final ValueChanged<String> onScriptChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.xlBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: BlocBuilder<SynthesisBloc, SynthesisState>(
          builder: (BuildContext context, SynthesisState state) {
            final bloc = context.read<SynthesisBloc>();
            final isGenerating = state.phase == SynthesisPhase.generating;
            final canGenerate = state.canGenerate;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TARGET VOICE',
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: NeutralPalette.n100.withValues(alpha: 0.65),
                  borderRadius: AppRadii.mdBorder,
                  child: InkWell(
                    onTap: onPickVoice,
                    borderRadius: AppRadii.mdBorder,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.12),
                            child: const Icon(Icons.person_rounded, color: AppColors.primaryPurple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              targetLabel,
                              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'INPUT TEXT',
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: scriptController,
                  maxLines: 4,
                  minLines: 3,
                  onChanged: onScriptChanged,
                  decoration: InputDecoration(
                    hintText: 'Type what you want the selected voice to say…',
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.75),
                    ),
                    filled: true,
                    fillColor: NeutralPalette.n100.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: AppRadii.mdBorder,
                      borderSide: BorderSide(color: NeutralPalette.n200.withValues(alpha: 0.9)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadii.mdBorder,
                      borderSide: BorderSide(color: NeutralPalette.n200.withValues(alpha: 0.9)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadii.mdBorder,
                      borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (!canGenerate || isGenerating)
                        ? null
                        : () => bloc.add(const SynthesisGenerateRequested()),
                    borderRadius: AppRadii.lgBorder,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: (!canGenerate || isGenerating)
                            ? LinearGradient(
                                colors: [
                                  AppColors.textSecondary.withValues(alpha: 0.35),
                                  AppColors.textSecondary.withValues(alpha: 0.25),
                                ],
                              )
                            : AppTheme.primaryGradient,
                        borderRadius: AppRadii.lgBorder,
                        boxShadow: canGenerate && !isGenerating
                            ? [
                                BoxShadow(
                                  color: PrimaryPalette.p500.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isGenerating)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                            const SizedBox(width: 10),
                            Text(
                              isGenerating ? 'Synthesizing…' : 'Synthesize Audio',
                              style: textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.selectedVoiceId == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Select a voice above to enable synthesis.',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
