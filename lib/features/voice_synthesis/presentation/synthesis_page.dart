import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/session/active_voice_profile_store.dart';
import 'bloc/synthesis_bloc.dart';
import 'bloc/synthesis_event.dart';
import 'bloc/synthesis_state.dart';

class SynthesisPage extends StatefulWidget {
  const SynthesisPage({super.key});

  @override
  State<SynthesisPage> createState() => _SynthesisPageState();
}

class _SynthesisPageState extends State<SynthesisPage> {
  final TextEditingController _controller = TextEditingController();
  double _pitch = 0.5;
  double _emotion = 0.55;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = context.read<SynthesisBloc>().state.text;
      if (t.isNotEmpty) {
        _controller.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
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
              Text(
                'LOCKED IN VOICE',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Consumer<ActiveVoiceProfileStore>(
                builder: (BuildContext context, ActiveVoiceProfileStore store, _) {
                  final profile = store.profile;
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
                      padding: const EdgeInsets.all(16),
                      child: profile == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No voice profile yet',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Record in the Record tab, then lock your voice to enable synthesis.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () => context.go('/record'),
                                  icon: const Icon(Icons.mic_rounded),
                                  label: const Text('Go to Record'),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.primaryPurple
                                      .withValues(alpha: 0.12),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.primaryPurple,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your voice',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Cloned • Studio quality',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        profile.id,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: AppColors.primaryPurple,
                                ),
                              ],
                            ),
                    ),
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
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bannerPurple,
                  borderRadius: AppRadii.xlBorder,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 12,
                      bottom: 8,
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        size: 72,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total generation time',
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '00:00:00',
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
          );
          },
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
  });

  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  final bool isPlaying;

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
        trailing: Text(
          'Today',
          style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
