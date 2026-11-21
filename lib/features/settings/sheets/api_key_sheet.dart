import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/settings_providers.dart';
import '../widgets/settings_sheet.dart';

/// Gemini API anahtarı formunu alt sayfada açar (ana ekrandaki karttan ve
/// ders ekranından da kullanılır).
Future<void> showApiKeySheet(BuildContext context) =>
    openSettingsSheet(context, 'Gemini API anahtarı', const ApiKeyForm());

/// Kendi Gemini anahtarını girme, gösterme/gizleme ve silme formu.
class ApiKeyForm extends ConsumerStatefulWidget {
  const ApiKeyForm({super.key});

  @override
  ConsumerState<ApiKeyForm> createState() => _ApiKeyFormState();
}

class _ApiKeyFormState extends ConsumerState<ApiKeyForm> {
  late final _controller = TextEditingController(
    text: ref.read(apiKeyProvider),
  );
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref.read(apiKeyProvider.notifier).save(_controller.text);
    if (!mounted) return;
    navigator.pop();
    // Önceki kayıt mesajı hâlâ görünüyorsa sırada beklemesin.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _controller.text.trim().isEmpty
                ? 'Kendi anahtarın silindi; uygulamayla gelen anahtar kullanılacak.'
                : 'Anahtar kaydedildi.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustomKey = ref.watch(apiKeyProvider).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dersler, hikayeler ve haftalık rapor Gemini ile üretilir. Kendi '
          'anahtarını girersen kota senin hesabından düşer.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Gemini API anahtarı',
            hintText: 'AIza…',
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Göster' : 'Gizle',
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Anahtarı aistudio.google.com/apikey adresinden ücretsiz alabilirsin. '
          'Anahtar bu cihazın güvenli kasasında şifreli saklanır.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),
        // Butonlar tema gereği tam genişlik ister (Size.fromHeight), bu
        // yüzden satırda esnek olmayan çocuk olarak bırakılamaz.
        Row(
          children: [
            if (hasCustomKey) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _controller.clear();
                    _save();
                  },
                  child: const Text('Sil'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
