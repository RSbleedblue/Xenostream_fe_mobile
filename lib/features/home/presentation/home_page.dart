import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/session/active_voice_profile_store.dart';
import '../../../shared/domain/voice_profile.dart';
import '../../voice_synthesis/presentation/bloc/synthesis_bloc.dart';
import '../../voice_synthesis/presentation/bloc/synthesis_event.dart';
import '../../voice_synthesis/presentation/bloc/synthesis_state.dart';

/// Figma-aligned home: feature hero, voice carousel, quick synthesis, recent activity.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _scriptController = TextEditingController();
  String _targetVoiceLabel = 'Sarah Jenkins';

  static const List<_DemoVoice> _demoVoices = <_DemoVoice>[
    _DemoVoice(name: 'Sarah Jenkins', subtitle: 'Studio Quality • Calm & Warm', badge: 'STUDIO'),
    _DemoVoice(name: 'Deep Narrator', subtitle: 'Documentary • Rich lows', badge: 'STUDIO'),
    _DemoVoice(name: 'Aurora Lite', subtitle: 'Social • Bright', badge: 'LITE'),
  ];

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetVoice(BuildContext context, VoiceProfile? profile) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (profile != null)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.15),
                    child: const Icon(Icons.verified_rounded, color: AppColors.primaryPurple),
                  ),
                  title: const Text('Your locked voice'),
                  subtitle: Text(profile.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, 'Your locked voice'),
                ),
              for (final v in _demoVoices)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: TertiaryPalette.t100,
                    child: Icon(Icons.graphic_eq_rounded, color: TertiaryPalette.t600),
                  ),
                  title: Text(v.name),
                  subtitle: Text(v.subtitle),
                  onTap: () => Navigator.pop(ctx, v.name),
                ),
            ],
          ),
        );
      },
    );
    if (choice != null && mounted) {
      setState(() => _targetVoiceLabel = choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ActiveVoiceProfileStore>();
    final profile = store.profile;
    final textTheme = Theme.of(context).textTheme;

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
                    profile: profile,
                    demos: _demoVoices,
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
                    targetLabel: _targetVoiceLabel,
                    profile: profile,
                    onPickVoice: () => _pickTargetVoice(context, profile),
                    onScriptChanged: (String v) =>
                        context.read<SynthesisBloc>().add(SynthesisTextChanged(v)),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Recent Activity',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<SynthesisBloc, SynthesisState>(
                    builder: (BuildContext context, SynthesisState state) {
                      final bloc = context.read<SynthesisBloc>();
                      final hasAudio = state.result != null;
                      final isPlaying = state.phase == SynthesisPhase.playing;
                      return Column(
                        children: [
                          if (hasAudio)
                            _RecentAudioTile(
                              title: state.result!.text,
                              subtitle: 'Your voice • just now',
                              trailingDownload: true,
                              leadingIsPlay: true,
                              isPlaying: isPlaying,
                              onPlay: () => bloc.add(const SynthesisPlayPauseToggled()),
                            ),
                          _RecentAudioTile(
                            title: 'Podcast_Intro_v2',
                            subtitle: 'Processing audio model…',
                            trailingDownload: false,
                            leadingIsPlay: false,
                            isPlaying: false,
                            showProgress: true,
                            onPlay: () {},
                          ),
                          if (!hasAudio)
                            _RecentAudioTile(
                              title: 'Documentary_Open',
                              subtitle: 'Deep Narrator • 02:45 • 2 hours ago',
                              trailingDownload: true,
                              leadingIsPlay: true,
                              isPlaying: false,
                              onPlay: () => context.go('/library'),
                            ),
                        ],
                      );
                    },
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

class _DemoVoice {
  const _DemoVoice({
    required this.name,
    required this.subtitle,
    required this.badge,
  });

  final String name;
  final String subtitle;
  final String badge;
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
                          'New Feature: Neural Echo 2.0',
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
    required this.profile,
    required this.demos,
  });

  final VoiceProfile? profile;
  final List<_DemoVoice> demos;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    if (profile != null) {
      cards.add(
        _VoiceCloneCard(
          name: 'Your locked voice',
          subtitle: 'Studio Quality • Your clone',
          badge: 'ACTIVE',
          highlight: true,
        ),
      );
    }
    for (final d in demos) {
      cards.add(
        _VoiceCloneCard(
          name: d.name,
          subtitle: d.subtitle,
          badge: d.badge,
          highlight: false,
        ),
      );
    }

    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int i) => cards[i],
      ),
    );
  }
}

class _VoiceCloneCard extends StatelessWidget {
  const _VoiceCloneCard({
    required this.name,
    required this.subtitle,
    required this.badge,
    required this.highlight,
  });

  final String name;
  final String subtitle;
  final String badge;
  final bool highlight;

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
    required this.profile,
    required this.onPickVoice,
    required this.onScriptChanged,
  });

  final TextEditingController scriptController;
  final String targetLabel;
  final VoiceProfile? profile;
  final VoidCallback onPickVoice;
  final ValueChanged<String> onScriptChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hintName = profile != null ? 'your locked voice' : 'Sarah';

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
            final canGenerate = state.canGenerate && profile != null;

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  targetLabel,
                                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (profile case final VoiceProfile p)
                                  Text(
                                    p.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                                  ),
                              ],
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
                    hintText: 'Type what you want $hintName to say…',
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
                if (profile == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Lock a voice in Record to enable synthesis.',
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

class _RecentAudioTile extends StatelessWidget {
  const _RecentAudioTile({
    required this.title,
    required this.subtitle,
    required this.trailingDownload,
    required this.leadingIsPlay,
    required this.isPlaying,
    required this.onPlay,
    this.showProgress = false,
  });

  final String title;
  final String subtitle;
  final bool trailingDownload;
  final bool leadingIsPlay;
  final bool isPlaying;
  final VoidCallback onPlay;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = title.length > 32 ? '${title.substring(0, 32)}…' : title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NeutralPalette.n100.withValues(alpha: 0.55),
          borderRadius: AppRadii.lgBorder,
          border: Border.all(color: NeutralPalette.n200.withValues(alpha: 0.65)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: showProgress ? TertiaryPalette.t100 : AppColors.card,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: showProgress ? null : onPlay,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          showProgress
                              ? Icons.sync_rounded
                              : (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          color: showProgress
                              ? AppColors.textSecondary
                              : AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (trailingDownload)
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.download_outlined, color: AppColors.textSecondary),
                    ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (showProgress) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: 0.42,
                    backgroundColor: NeutralPalette.n200,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
