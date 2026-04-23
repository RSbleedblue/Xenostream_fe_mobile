import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../core/constants/recording_constants.dart';
import '../../../core/utils/format_duration.dart';
import 'bloc/enrollment_bloc.dart';
import 'bloc/enrollment_event.dart';
import 'bloc/enrollment_state.dart';

class EnrollmentPage extends StatefulWidget {
  const EnrollmentPage({super.key});

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  final _displayNameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _tagsController = TextEditingController();
  final _metadataController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_onFormChanged);
    _displayNameController.dispose();
    _detailsController.dispose();
    _tagsController.dispose();
    _metadataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<EnrollmentBloc, EnrollmentState>(
          listenWhen: (EnrollmentState prev, EnrollmentState curr) =>
              prev.phase != curr.phase &&
              (curr.phase == EnrollmentPhase.failure ||
                  curr.phase == EnrollmentPhase.success),
          listener: (BuildContext context, EnrollmentState state) {
            if (state.phase == EnrollmentPhase.failure &&
                state.errorMessage != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
            if (state.phase == EnrollmentPhase.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice locked successfully.')),
              );
            }
          },
          builder: (BuildContext context, EnrollmentState state) {
            final bloc = context.read<EnrollmentBloc>();
            final isRecording = state.phase == EnrollmentPhase.recording;
            final isSubmitting = state.phase == EnrollmentPhase.submitting;
            final isReady = state.phase == EnrollmentPhase.readyToSubmit;
            final progress = switch (state.phase) {
              EnrollmentPhase.recording =>
                state.elapsed.inMilliseconds /
                    kEnrollmentMaxDuration.inMilliseconds,
              EnrollmentPhase.readyToSubmit => 1.0,
              _ => 0.0,
            };

            InputDecoration filledField(
              String label, {
              String? hint,
              String? helper,
              Widget? prefix,
              int maxLines = 1,
            }) {
              return InputDecoration(
                labelText: label,
                hintText: hint,
                helperText: helper,
                alignLabelWithHint: maxLines > 1,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                prefixIcon: maxLines == 1 ? prefix : null,
                border: OutlineInputBorder(
                  borderRadius: AppRadii.mdBorder,
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.mdBorder,
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.35),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.mdBorder,
                  borderSide: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
                      const TextSpan(text: 'Clone your '),
                      TextSpan(
                        text: 'voice',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Record up to two minutes, review the clip, then add details before '
                  'saving to the server.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                _StepPill(
                  number: 1,
                  label: 'Record',
                  isActive: isRecording,
                  isDone: isReady || isSubmitting,
                ),
                const SizedBox(height: 16),

                // ---- Recording progress card ----
                DecoratedBox(
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: AppRadii.mdBorder,
                          child: LinearProgressIndicator(
                            value: (isRecording || isReady)
                                ? progress.clamp(0, 1)
                                : 0,
                            minHeight: 10,
                            backgroundColor: AppColors.chipBackground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${formatDurationMmSs(state.elapsed)} / ${formatDurationMmSs(kEnrollmentMaxDuration)}',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Record / Stop buttons ----
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (isRecording || isSubmitting)
                            ? null
                            : () => bloc.add(const EnrollmentStartRequested()),
                        icon: const Icon(Icons.fiber_manual_record),
                        label: Text(isReady ? 'Re-record' : 'Record'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isRecording
                            ? () => bloc.add(const EnrollmentStopRequested())
                            : null,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),

                // ---- Playback & name section (shown after recording) ----
                if (isReady || isSubmitting) ...[
                  const SizedBox(height: 24),
                  _StepPill(
                    number: 2,
                    label: 'Review & save',
                    isActive: isReady,
                    isDone: false,
                  ),
                  const SizedBox(height: 12),
                  _PlaybackCard(state: state, bloc: bloc),
                  const SizedBox(height: 20),
                  Text(
                    'Voice details for the server',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Display name and optional fields are sent with your file when you lock.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    elevation: 0,
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.lgBorder,
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _displayNameController,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 200,
                            decoration: filledField(
                              'Display name',
                              prefix: const Icon(
                                Icons.badge_outlined,
                                size: 22,
                              ),
                              hint: 'e.g. My work voice (required for save)',
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _detailsController,
                            maxLength: 2000,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: filledField(
                              'Description & notes',
                              hint: 'Optional — up to 2000 characters',
                              maxLines: 3,
                            ),
                          ),
                          Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: colorScheme.outline.withValues(
                                alpha: 0.2,
                              ),
                              splashColor: AppColors.primaryPurple.withValues(
                                alpha: 0.08,
                              ),
                            ),
                            child: ExpansionTile(
                              title: Text(
                                'More fields',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Tags and JSON metadata (optional API fields)',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                0,
                                0,
                                0,
                                8,
                              ),
                              children: [
                                TextField(
                                  controller: _tagsController,
                                  textCapitalization: TextCapitalization.none,
                                  decoration: filledField(
                                    'Tags',
                                    hint: 'e.g. personal, english, podcast',
                                    prefix: const Icon(
                                      Icons.sell_outlined,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _metadataController,
                                  maxLines: 3,
                                  textCapitalization: TextCapitalization.none,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                  decoration: filledField(
                                    'Metadata (JSON object)',
                                    hint: r'{"app":"xeno","version":"1"}',
                                    helper:
                                        'A JSON object with string values, max flexibility for your app.',
                                    maxLines: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        state.canSubmit &&
                            !isSubmitting &&
                            _displayNameController.text.trim().isNotEmpty
                        ? () {
                            final rawMeta = _metadataController.text.trim();
                            if (rawMeta.isNotEmpty) {
                              try {
                                final decoded = jsonDecode(rawMeta);
                                if (decoded is! Map) {
                                  _showError(
                                    context,
                                    'Metadata must be a JSON object, e.g. {"key":"value"}.',
                                  );
                                  return;
                                }
                              } catch (_) {
                                _showError(
                                  context,
                                  'Metadata is not valid JSON.',
                                );
                                return;
                              }
                            }
                            bloc.add(
                              EnrollmentSubmitRequested(
                                displayName: _displayNameController.text,
                                details: _detailsController.text,
                                tags: _tagsController.text,
                                metadata: _metadataController.text,
                              ),
                            );
                          }
                        : null,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline),
                    label: Text(isSubmitting ? 'Locking voice…' : 'Lock voice'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () => bloc.add(
                            const EnrollmentDeleteRecordingRequested(),
                          ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete recording'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ],

                // ---- Idle / recording phase: simpler reset ----
                if (!isReady &&
                    !isSubmitting &&
                    state.phase != EnrollmentPhase.success) ...[
                  const SizedBox(height: 12),
                  if (state.phase != EnrollmentPhase.idle)
                    TextButton(
                      onPressed: () =>
                          bloc.add(const EnrollmentResetRequested()),
                      child: const Text('Reset session'),
                    ),
                ],

                // ---- Success state ----
                if (state.phase == EnrollmentPhase.success) ...[
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: AppRadii.lgBorder,
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voice locked!',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                if (state.profile != null)
                                  Text(
                                    state.profile!.displayName,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/library'),
                    child: const Text('Continue to Library'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      _displayNameController.clear();
                      _detailsController.clear();
                      _tagsController.clear();
                      _metadataController.clear();
                      bloc.add(const EnrollmentResetRequested());
                    },
                    child: const Text('Record another voice'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Step pill (record flow)
// -----------------------------------------------------------------------------

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  final int number;
  final String label;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = isDone
        ? const Color(0xFF0D9488)
        : (isActive
              ? AppColors.primaryPurple
              : AppColors.textSecondary.withValues(alpha: 0.4));

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (isActive || isDone)
                ? AppColors.primaryPurple.withValues(alpha: 0.12)
                : AppColors.chipBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: (isActive || isDone)
                  ? color
                  : color.withValues(alpha: 0.3),
            ),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 18, color: Color(0xFF0D9488))
              : Text(
                  '$number',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: (isActive || isDone) ? color : null,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Playback card
// -----------------------------------------------------------------------------

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({required this.state, required this.bloc});

  final EnrollmentState state;
  final EnrollmentBloc bloc;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totalMs = state.playbackDuration.inMilliseconds;
    final posMs = state.playbackPosition.inMilliseconds;
    final sliderMax = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final isReady = state.phase == EnrollmentPhase.readyToSubmit;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.xlBorder,
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: AppRadii.mdBorder,
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.primaryPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview your take',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plays on your speaker. Android emulators and iOS simulators '
                        'often only play a click or beep for mic audio—use a real phone '
                        'or tablet to verify recording and preview.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isReady &&
                state.previewError == null &&
                totalMs == 0 &&
                !state.isPlaying) ...[
              const SizedBox(height: 8),
              Text(
                'Tap play to listen. On a real device, check media volume; emulators are unreliable.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 4),
            if (state.previewError != null) ...[
              const SizedBox(height: 4),
              Text(
                state.previewError!,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Semantics(
                  label: state.isPlaying ? 'Pause' : 'Play',
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton.filledTonal(
                      onPressed: isReady && state.previewError == null
                          ? () => bloc.add(const EnrollmentPlaybackToggled())
                          : null,
                      icon: Icon(
                        state.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple.withValues(
                          alpha: 0.2,
                        ),
                        foregroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: AppColors.primaryPurple,
                      inactiveTrackColor: AppColors.chipBackground,
                      thumbColor: AppColors.primaryPurple,
                    ),
                    child: Slider(
                      value: posMs.toDouble().clamp(0, sliderMax),
                      max: sliderMax,
                      onChanged: state.previewError == null
                          ? (v) => bloc.add(
                              EnrollmentPlaybackSeekRequested(
                                Duration(milliseconds: v.round()),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDurationMmSs(state.playbackPosition),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    formatDurationMmSs(state.playbackDuration),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
