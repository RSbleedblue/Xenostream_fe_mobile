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

class EnrollmentPage extends StatelessWidget {
  const EnrollmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocConsumer<EnrollmentBloc, EnrollmentState>(
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
          final canStop = isRecording;
          final progress = switch (state.phase) {
            EnrollmentPhase.recording =>
              state.elapsed.inMilliseconds /
                  kEnrollmentMaxDuration.inMilliseconds,
            EnrollmentPhase.readyToSubmit => 1.0,
            _ => 0.0,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                    const TextSpan(text: 'Capture '),
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
              Text(
                'Speak naturally for up to two minutes. Stop when you are done, then lock your voice.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
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
                          value:
                              (isRecording ||
                                  state.phase == EnrollmentPhase.readyToSubmit)
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
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (isRecording || isSubmitting)
                          ? null
                          : () => bloc.add(const EnrollmentStartRequested()),
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Record'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canStop
                          ? () => bloc.add(const EnrollmentStopRequested())
                          : null,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state.canSubmit && !isSubmitting
                    ? () => bloc.add(const EnrollmentSubmitRequested())
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
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => bloc.add(const EnrollmentResetRequested()),
                child: const Text('Reset session'),
              ),
              if (state.phase == EnrollmentPhase.success) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/library'),
                  child: const Text('Continue to Library'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
