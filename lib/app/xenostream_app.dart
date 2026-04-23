import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../core/api/api_config.dart';
import '../core/api/xenostream_api_client.dart';
import '../core/session/active_voice_profile_store.dart';
import '../features/voice_enrollment/data/voice_enrollment_repository.dart';
import '../features/voice_synthesis/data/voice_synthesis_repository.dart';
import '../features/voice_synthesis/presentation/bloc/synthesis_bloc.dart';
import 'app_router.dart';
import 'theme/app_theme.dart';

class XenoStreamApp extends StatefulWidget {
  const XenoStreamApp({
    super.key,
    required this.apiConfig,
    required this.apiClient,
    required this.activeVoiceProfileStore,
    required this.voiceEnrollmentRepository,
    required this.voiceSynthesisRepository,
  });

  final ApiConfig apiConfig;
  final XenoStreamApiClient apiClient;
  final ActiveVoiceProfileStore activeVoiceProfileStore;
  final VoiceEnrollmentRepository voiceEnrollmentRepository;
  final VoiceSynthesisRepository voiceSynthesisRepository;

  @override
  State<XenoStreamApp> createState() => _XenoStreamAppState();
}

class _XenoStreamAppState extends State<XenoStreamApp> {
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiConfig>.value(value: widget.apiConfig),
        Provider<XenoStreamApiClient>.value(value: widget.apiClient),
        ChangeNotifierProvider<ActiveVoiceProfileStore>.value(
          value: widget.activeVoiceProfileStore,
        ),
        Provider<VoiceEnrollmentRepository>.value(
          value: widget.voiceEnrollmentRepository,
        ),
        Provider<VoiceSynthesisRepository>.value(
          value: widget.voiceSynthesisRepository,
        ),
      ],
      child: Builder(
        builder: (BuildContext context) {
          return BlocProvider<SynthesisBloc>(
            create: (BuildContext ctx) => SynthesisBloc(
              repository: ctx.read<VoiceSynthesisRepository>(),
              activeVoiceProfileStore: ctx.read<ActiveVoiceProfileStore>(),
              audioPlayer: AudioPlayer(),
            ),
            child: MaterialApp.router(
              title: 'XenoStream',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              themeMode: ThemeMode.light,
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
