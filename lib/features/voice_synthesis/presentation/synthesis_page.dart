import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/xenostream_api_client.dart';
import '../../../core/session/active_voice_profile_store.dart';
import '../../voice_enrollment/data/voice_enrollment_repository.dart';
import 'bloc/synthesis_bloc.dart';
import 'bloc/synthesis_event.dart';
import 'bloc/synthesis_state.dart';

class SynthesisPage extends StatefulWidget {
  const SynthesisPage({super.key});

  @override
  State<SynthesisPage> createState() => _SynthesisPageState();
}

class _SynthesisPageState extends State<SynthesisPage>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  double _pitch = 0.5;
  double _emotion = 0.55;

  List<VoiceUploadResult> _apiVoices = [];
  bool _voicesLoading = true;
  String? _voicesError;
  late final ActiveVoiceProfileStore _profileStore;

  @override
  void initState() {
    super.initState();
    _profileStore = context.read<ActiveVoiceProfileStore>();
    _profileStore.addListener(_onProfileStoreChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = context.read<SynthesisBloc>().state.text;
      if (t.isNotEmpty) {
        _controller.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      }
      _fetchVoices();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchVoices();
    }
  }

  void _onProfileStoreChanged() {
    _fetchVoices();
  }

  Future<void> _fetchVoices() async {
    if (!mounted) return;
    setState(() {
      _voicesError = null;
      _voicesLoading = true;
    });
    try {
      final client = context.read<XenoStreamApiClient>();
      final voices = await client.listVoices();
      if (!mounted) return;
      setState(() {
        _apiVoices = voices;
        _voicesLoading = false;
      });
      if (!mounted) return;
      _syncSelectionWithVoiceList(voices);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voicesLoading = false;
        _voicesError = e.toString();
      });
    }
  }

  /// Aligns the selected [SynthesisState.selectedVoiceId] with the current server list.
  void _syncSelectionWithVoiceList(List<VoiceUploadResult> voices) {
    final bloc = context.read<SynthesisBloc>();
    final current = bloc.state.selectedVoiceId;
    if (current != null && voices.any((v) => v.voiceId == current)) {
      return;
    }
    if (voices.isNotEmpty) {
      bloc.add(SynthesisVoiceSelected(voices.first.voiceId));
      return;
    }
    final p = _profileStore.profile;
    if (p != null) {
      bloc.add(SynthesisVoiceSelected(p.id));
    } else {
      bloc.add(const SynthesisVoiceCleared());
    }
  }

  Future<void> _deleteServerVoice(String voiceId) async {
    final store = _profileStore;
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete voice?'),
        content: const Text(
          'This removes the voice on the XenoStream server. You can record a new one anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final repo = context.read<VoiceEnrollmentRepository>();
      await repo.deleteVoice(voiceId: voiceId);
      if (store.profile?.id == voiceId) {
        store.clear();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Voice removed from the server.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
      return;
    }
    await _fetchVoices();
  }

  @override
  void dispose() {
    _profileStore.removeListener(_onProfileStoreChanged);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Scrolling list height (keeps the library section from stretching down the page).
  double _voiceLibraryScrollHeight(BuildContext context) {
    return (MediaQuery.sizeOf(context).height * 0.32).clamp(220, 400);
  }

  /// Primary label: server [VoiceUploadResult.displayName], else file stem / id.
  static String _displayNameFor(VoiceUploadResult v) {
    final name = v.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    if (v.filePath.isNotEmpty) {
      final segs = v.filePath.split(RegExp(r'[\\/]'));
      final filename = segs.isNotEmpty ? segs.last : v.filePath;
      final dot = filename.lastIndexOf('.');
      final stem = dot > 0 ? filename.substring(0, dot) : filename;
      if (stem.length <= 18) {
        return stem;
      }
    }
    if (v.voiceId.length <= 12) {
      return v.voiceId;
    }
    return '${v.voiceId.substring(0, 8)}…';
  }

  static String? _tagLineFor(VoiceUploadResult v) {
    final t = v.tags;
    if (t != null && t.isNotEmpty) {
      return t.map((e) => e.toString().trim()).join(', ');
    }
    return null;
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  String _pitchLabel(double v) {
    if (v < 0.35) return 'LOW';
    if (v > 0.65) return 'HIGH';
    return 'BALANCED';
  }

  String _emotionLabel(double v) {
    if (v < 0.35) return 'NEUTRAL';
    if (v > 0.65) return 'ATMOSPHERIC';
    return 'WARM';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocListener<SynthesisBloc, SynthesisState>(
        listenWhen: (SynthesisState prev, SynthesisState curr) =>
            prev.text != curr.text,
        listener: (BuildContext context, SynthesisState state) {
          if (_controller.text == state.text) return;
          _controller.value = TextEditingValue(
            text: state.text,
            selection: TextSelection.collapsed(
              offset: state.text.length.clamp(0, state.text.length),
            ),
          );
        },
        child: BlocConsumer<SynthesisBloc, SynthesisState>(
          listenWhen: (SynthesisState prev, SynthesisState curr) =>
              prev.phase != curr.phase && curr.phase == SynthesisPhase.failure,
          listener: (BuildContext context, SynthesisState state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          },
          builder: (BuildContext context, SynthesisState state) {
          final bloc = context.read<SynthesisBloc>();
          final isGenerating = state.phase == SynthesisPhase.generating;
          final hasAudio = state.result != null;
          final isPlaying = state.phase == SynthesisPhase.playing;
          final words = _wordCount(state.text);

          return RefreshIndicator(
            onRefresh: _fetchVoices,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
              Text(
                'WORKSPACE',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    const TextSpan(text: 'Synthesize '),
                    TextSpan(
                      text: 'Voice',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.go('/record'),
                icon: const Icon(Icons.mic_rounded, size: 20),
                label: const Text('Add Voice'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              _ScriptCard(
                controller: _controller,
                wordCount: words,
                onChanged: (String value) =>
                    bloc.add(SynthesisTextChanged(value)),
                isGenerating: isGenerating,
                canGenerate: state.canGenerate,
                onGenerate: () => bloc.add(const SynthesisGenerateRequested()),
                hasAudio: hasAudio,
                isPlaying: isPlaying,
                onPlayPause: () => bloc.add(const SynthesisPlayPauseToggled()),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOICE LIBRARY',
                          style: textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.1,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'These are the voices you have saved. Tap one to use it for '
                          'Generate audio, or add more under Record.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _voicesLoading ? null : _fetchVoices,
                    tooltip: 'Refresh list',
                    icon: _voicesLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BlocBuilder<SynthesisBloc, SynthesisState>(
                buildWhen: (SynthesisState a, SynthesisState b) =>
                    a.selectedVoiceId != b.selectedVoiceId,
                builder: (BuildContext context, SynthesisState sState) {
                  final listH = _voiceLibraryScrollHeight(context);
                  return ListenableBuilder(
                    listenable: _profileStore,
                    builder: (BuildContext c, _) {
                      if (_voicesLoading && _apiVoices.isEmpty) {
                        return _VoiceLibraryCardChild(
                          child: SizedBox(
                            height: listH,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }
                      if (_voicesError != null) {
                        return _VoiceLibraryCardChild(
                          child: SizedBox(
                            height: listH,
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Could not load your voices',
                                      textAlign: TextAlign.center,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _voicesError!,
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.tonal(
                                      onPressed: _fetchVoices,
                                      child: const Text('Try again'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      if (_apiVoices.isEmpty) {
                        return _EmptyVoiceLibrary(
                          textTheme: textTheme,
                          onGoRecord: () => context.go('/record'),
                        );
                      }
                      return _VoiceLibraryCardChild(
                        child: SizedBox(
                          height: listH,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: _apiVoices.length,
                            separatorBuilder: (BuildContext context, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (BuildContext c2, int i) {
                              final v = _apiVoices[i];
                              return _SelectVoiceRow(
                                key: ValueKey(v.voiceId),
                                title: _displayNameFor(v),
                                subtitle: v.details?.trim().isNotEmpty == true
                                    ? v.details
                                    : 'ID ${v.voiceId.length > 14 ? '${v.voiceId.substring(0, 12)}…' : v.voiceId}',
                                tagLine: _tagLineFor(v),
                                isSelected: sState.selectedVoiceId == v.voiceId,
                                isOnDevice: _profileStore.profile?.id ==
                                    v.voiceId,
                                onSelect: () => c2
                                    .read<SynthesisBloc>()
                                    .add(SynthesisVoiceSelected(v.voiceId)),
                                onDelete: () => _deleteServerVoice(v.voiceId),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'PITCH VARIATION',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _pitch,
                      onChanged: (double v) => setState(() => _pitch = v),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text(
                      _pitchLabel(_pitch),
                      textAlign: TextAlign.end,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'EMOTIONAL RESONANCE',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _emotion,
                      onChanged: (double v) => setState(() => _emotion = v),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text(
                      _emotionLabel(_emotion),
                      textAlign: TextAlign.end,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent creations',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('History — coming soon')),
                      );
                    },
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasAudio)
                _RecentTile(
                  title: state.result!.text,
                  subtitle: 'Preview clip • just now',
                  onPlay: () => bloc.add(const SynthesisPlayPauseToggled()),
                  isPlaying: isPlaying,
                  onDelete: () => bloc.add(const SynthesisResultCleared()),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Generated clips will appear here.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
            ),
          );
          },
        ),
      ),
    );
  }
}

/// Rounded “card” shell used by the voice list (loading, error, empty) above.
class _VoiceLibraryCardChild extends StatelessWidget {
  const _VoiceLibraryCardChild({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }
}

class _EmptyVoiceLibrary extends StatelessWidget {
  const _EmptyVoiceLibrary({
    required this.textTheme,
    required this.onGoRecord,
  });

  final TextTheme textTheme;
  final VoidCallback onGoRecord;

  @override
  Widget build(BuildContext context) {
    return _VoiceLibraryCardChild(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TertiaryPalette.t100,
                    borderRadius: AppRadii.mdBorder,
                  ),
                  child: Icon(
                    Icons.cloud_off_outlined,
                    color: TertiaryPalette.t600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No voices here yet',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Record a voice in the Record tab, then it will show up in this list. '
              'Pull to refresh (or use the button above) after you have saved a voice.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onGoRecord,
              icon: const Icon(Icons.mic_rounded, size: 20),
              label: const Text('Go to record'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectVoiceRow extends StatelessWidget {
  const _SelectVoiceRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tagLine,
    required this.isSelected,
    required this.isOnDevice,
    required this.onSelect,
    required this.onDelete,
  });

  final String title;
  final String? subtitle;
  final String? tagLine;
  final bool isSelected;
  final bool isOnDevice;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: AppRadii.lgBorder,
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryPurple.withValues(alpha: 0.08)
                : AppColors.card,
            borderRadius: AppRadii.lgBorder,
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryPurple
                  : AppColors.primaryPurple.withValues(alpha: 0.1),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: TertiaryPalette.t100,
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: TertiaryPalette.t600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isOnDevice)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _MiniChip(
                                label: 'This device',
                                onPrimary: TertiaryPalette.t600,
                                background: TertiaryPalette.t100,
                              ),
                            ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _MiniChip(
                                label: 'Synthesis',
                                onPrimary: AppColors.primaryPurple,
                                background: AppColors.primaryPurple
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (tagLine != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tags',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final raw in tagLine!.split(','))
                              if (raw.trim().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.chipBackground,
                                    borderRadius: AppRadii.smBorder,
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    raw.trim(),
                                    style: textTheme.labelSmall,
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (String value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext ctx) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete from server',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.onPrimary,
    required this.background,
  });

  final String label;
  final Color onPrimary;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ScriptCard extends StatelessWidget {
  const _ScriptCard({
    required this.controller,
    required this.wordCount,
    required this.onChanged,
    required this.isGenerating,
    required this.canGenerate,
    required this.onGenerate,
    required this.hasAudio,
    required this.isPlaying,
    required this.onPlayPause,
  });

  final TextEditingController controller;
  final int wordCount;
  final ValueChanged<String> onChanged;
  final bool isGenerating;
  final bool canGenerate;
  final VoidCallback onGenerate;
  final bool hasAudio;
  final bool isPlaying;
  final VoidCallback onPlayPause;

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
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Script content',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '$wordCount WORDS',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 8,
              minLines: 5,
              textInputAction: TextInputAction.newline,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText:
                    'Type or paste your narrative here to bring it to life…',
                hintStyle: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.75),
                ),
                border: InputBorder.none,
                filled: true,
                fillColor: AppColors.canvas,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Text size',
                  onPressed: () {},
                  icon: const Icon(Icons.text_fields_rounded),
                  color: AppColors.textSecondary,
                ),
                IconButton(
                  tooltip: 'Translate',
                  onPressed: () {},
                  icon: const Icon(Icons.translate_rounded),
                  color: AppColors.textSecondary,
                ),
                IconButton(
                  tooltip: 'Polish',
                  onPressed: () {},
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (!canGenerate || isGenerating) ? null : onGenerate,
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
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 10),
                        Text(
                          isGenerating ? 'Generating…' : 'Generate audio',
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
            if (hasAudio) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isGenerating ? null : onPlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isPlaying ? 'Pause preview' : 'Play preview'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.title,
    required this.subtitle,
    required this.onPlay,
    required this.isPlaying,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  final bool isPlaying;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = title.length > 36 ? '${title.substring(0, 36)}…' : title;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.chipBackground.withValues(alpha: 0.65),
        borderRadius: AppRadii.lgBorder,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Material(
          color: AppColors.card,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPlay,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.primaryPurple,
              ),
            ),
          ),
        ),
        title: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.mdBorder),
          onSelected: (value) {
            if (value == 'delete' && onDelete != null) onDelete!();
          },
          itemBuilder: (_) => [
            if (onDelete != null)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
