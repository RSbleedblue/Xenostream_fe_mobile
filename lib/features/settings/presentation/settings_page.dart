import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../core/api/xenostream_api_client.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  bool _obscureKey = true;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final client = context.read<XenoStreamApiClient>();
    _urlController = TextEditingController(text: client.config.baseUrl);
    _keyController = TextEditingController(text: client.config.apiKey ?? '');
    _urlController.addListener(_markDirty);
    _keyController.addListener(_markDirty);
  }

  void _markDirty() {
    final client = context.read<XenoStreamApiClient>();
    final isDirty = _urlController.text.trim() != client.config.baseUrl ||
        _keyController.text.trim() != (client.config.apiKey ?? '');
    if (isDirty != _dirty) setState(() => _dirty = isDirty);
  }

  Future<void> _save() async {
    final client = context.read<XenoStreamApiClient>();
    final previousConfig = client.config;
    final newConfig = previousConfig.copyWith(
      baseUrl: _urlController.text.trim(),
      apiKey: _keyController.text.trim(),
    );
    client.config = newConfig;
    setState(() {
      _saving = true;
      _dirty = false;
    });

    try {
      final ok = await client.healthz();
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to backend.')),
        );
      } else {
        client.config = previousConfig;
        _dirty = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backend unreachable. Settings reverted.')),
        );
      }
    } catch (e) {
      client.config = previousConfig;
      if (!mounted) return;
      setState(() => _dirty = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed — settings reverted. $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          sliver: SliverList.list(
            children: [
              Text(
                'SETTINGS',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preferences',
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadii.lgBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Backend Connection',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'BASE URL',
                        style: textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.0,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'http://10.0.2.2:8000',
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(Icons.link_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: AppRadii.mdBorder,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'API KEY',
                        style: textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.0,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _keyController,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          hintText: 'Enter your API key',
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          prefixIcon:
                              const Icon(Icons.vpn_key_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadii.mdBorder,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: (_dirty && !_saving) ? _save : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'Testing...' : 'Save & Test'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: For Android emulator use http://10.0.2.2:8000. '
                'For a physical device, use your PC\'s LAN IP.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
