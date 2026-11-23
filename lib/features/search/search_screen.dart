import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/mascot.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/search.dart';
import '../program/calendar_day_sheet.dart';

/// Aramanın kaynak verisi; ekran açıkken bir kez okunur.
final _searchSourceProvider =
    FutureProvider.autoDispose<
      ({
        List<Flashcard> cards,
        List<Mistake> mistakes,
        List<WeeklyPlanDay> plan,
      })
    >((ref) async {
      final db = ref.read(databaseProvider);
      final repository = ref.read(repositoryProvider);
      return (
        cards: await db.select(db.flashcards).get(),
        mistakes: await repository.mistakes(),
        plan: await repository.allPlanDays(),
      );
    });

/// Kelimelerde, hata defterinde ve program konularında arama.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = ref.watch(_searchSourceProvider).value;
    final results = source == null
        ? const SearchResults()
        : searchAll(
            query: _query,
            cards: source.cards,
            mistakes: source.mistakes,
            plan: source.plan,
          );
    final searching = searchFold(_query).length >= 2;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Kelime, konu ya da hata ara',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Temizle',
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: !searching
          ? _Hint(
              text:
                  'Öğrendiğin kelimeleri, hata defterini ve programındaki '
                  'konuları ara. Örneğin "past perfect" ya da "seyahat".',
            )
          : results.isEmpty
          ? _Hint(text: '"$_query" için sonuç yok.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (results.topics.isNotEmpty) ...[
                  _Header('Konular', results.topics.length),
                  for (final t in results.topics)
                    ListTile(
                      leading: const Icon(Icons.menu_book_rounded),
                      title: Text(t.day.grammarTopic),
                      subtitle: Text(
                        '${longDate(t.date)} · ${t.day.vocabTheme}',
                      ),
                      trailing: t.day.status == 'completed'
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => showCalendarDaySheet(context, t.date),
                    ),
                ],
                if (results.words.isNotEmpty) ...[
                  _Header('Kelimeler', results.words.length),
                  for (final c in results.words)
                    ListTile(
                      leading: const Icon(Icons.style_rounded),
                      title: Text(c.word),
                      subtitle: Text(
                        c.exampleSentence.isEmpty
                            ? c.meaning
                            : '${c.meaning} · ${c.exampleSentence}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                if (results.mistakes.isNotEmpty) ...[
                  _Header('Hata defteri', results.mistakes.length),
                  for (final m in results.mistakes)
                    ListTile(
                      leading: Icon(
                        m.resolved
                            ? Icons.check_circle_outline_rounded
                            : Icons.edit_note_rounded,
                      ),
                      title: Text(m.item),
                      subtitle: Text(
                        m.context,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.count);

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '$title · $count',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EquippedPace(mood: PaceMood.study, size: 110),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
