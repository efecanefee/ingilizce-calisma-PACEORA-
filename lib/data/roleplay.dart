import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gemini_json.dart';

/// AI ile rol yapma sohbeti: senaryolar, mesajlar ve kayıtlar.

/// Hazır bir konuşma durumu.
class RoleplayScenario {
  const RoleplayScenario({
    required this.id,
    required this.emoji,
    required this.title,
    required this.task,
    required this.aiRole,
    required this.opening,
  });

  final String id;
  final String emoji;

  /// Türkçe başlık.
  final String title;

  /// Öğrencinin görevi (Türkçe); hedefe ulaşıldı mı buna göre değerlendirilir.
  final String task;

  /// Modelin oynadığı karakter (İngilizce, modele gider).
  final String aiRole;

  /// Karakterin ilk cümlesi.
  final String opening;
}

const roleplayScenarios = [
  RoleplayScenario(
    id: 'cafe',
    emoji: '☕',
    title: 'Kafede sipariş',
    task: 'Bir içecek ve bir yiyecek sipariş et, fiyatı sor ve ödemeyi yap.',
    aiRole: 'a friendly barista at a small coffee shop in London',
    opening: 'Hi there! What can I get for you today?',
  ),
  RoleplayScenario(
    id: 'hotel',
    emoji: '🏨',
    title: 'Otelde giriş',
    task:
        'Rezervasyonunla giriş yap, kahvaltı saatini ve Wi-Fi şifresini öğren.',
    aiRole: 'a receptionist at a hotel in New York',
    opening: 'Good evening and welcome! Do you have a reservation with us?',
  ),
  RoleplayScenario(
    id: 'directions',
    emoji: '🗺️',
    title: 'Yol tarifi',
    task: 'En yakın metro istasyonunu sor ve tarifi anladığını teyit et.',
    aiRole: 'a helpful local person on a busy street in Dublin',
    opening: 'You look a bit lost. Can I help you find something?',
  ),
  RoleplayScenario(
    id: 'doctor',
    emoji: '🩺',
    title: 'Doktorda',
    task:
        'Şikayetini anlat, ne zamandır sürdüğünü söyle ve ilacı nasıl '
        'kullanacağını sor.',
    aiRole: 'a calm general practitioner (doctor) at a clinic',
    opening: 'Hello, please have a seat. What seems to be the problem today?',
  ),
  RoleplayScenario(
    id: 'interview',
    emoji: '💼',
    title: 'İş görüşmesi',
    task: 'Kendini tanıt, deneyimini anlat ve şirket hakkında bir soru sor.',
    aiRole:
        'an HR manager interviewing a candidate for a marketing assistant '
        'job',
    opening:
        'Thanks for coming in today. Could you tell me a little about '
        'yourself?',
  ),
  RoleplayScenario(
    id: 'shopping',
    emoji: '🛍️',
    title: 'Mağazada iade',
    task:
        'Bir ürünü neden iade etmek istediğini açıkla ve değişim ya da '
        'para iadesi iste.',
    aiRole:
        'a shop assistant at the customer service desk of a clothing '
        'store',
    opening: 'Hello! How can I help you today?',
  ),
  RoleplayScenario(
    id: 'airport',
    emoji: '✈️',
    title: 'Havalimanında',
    task:
        'Uçuşun için check-in yap, cam kenarı koltuk iste ve bagaj '
        'sınırını sor.',
    aiRole: 'an airline check-in agent at an international airport',
    opening: 'Good morning! May I see your passport and ticket, please?',
  ),
  RoleplayScenario(
    id: 'new_friend',
    emoji: '👋',
    title: 'Yeni arkadaş',
    task:
        'Kendinden bahset, karşındakine hobilerini sor ve hafta sonu için '
        'bir plan öner.',
    aiRole: 'a friendly exchange student you just met at a university event',
    opening: "Hey! I don't think we've met. I'm Sam. Are you a student here?",
  ),
];

RoleplayScenario? scenarioById(String id) =>
    roleplayScenarios.where((s) => s.id == id).firstOrNull;

/// Öğrencinin bir mesajındaki düzeltme.
class Correction {
  const Correction({required this.corrected, required this.explanationTr});

  /// Mesajın doğru hali.
  final String corrected;

  /// Kısa Türkçe açıklama.
  final String explanationTr;
}

enum Speaker { ai, user }

class ChatMessage {
  const ChatMessage(
    this.speaker,
    this.text, {
    this.correction,
    this.understood = true,
  });

  /// Öğrenci mesajı anlaşıldı mı; anlaşılmayan mesaj XP'ye sayılmaz.
  final bool understood;

  final Speaker speaker;
  final String text;

  /// Yalnızca öğrenci mesajlarında; null ise mesaj doğru bulundu.
  final Correction? correction;

  ChatMessage evaluated(RoleplayTurn turn) => ChatMessage(
    speaker,
    text,
    correction: turn.correction,
    understood: turn.understood,
  );
}

/// Bir sohbet turunda modelin cevabı.
class RoleplayTurn {
  const RoleplayTurn({
    required this.reply,
    this.correction,
    this.goalReached = false,
    this.understood = true,
  });

  /// Öğrencinin son mesajı anlaşıldı mı; değilse karakter tekrar ister,
  /// düzeltme ve görev ilerlemesi sayılmaz.
  final bool understood;

  /// Karakterin İngilizce cevabı.
  final String reply;
  final Correction? correction;

  /// Öğrenci görevi tamamladı mı?
  final bool goalReached;

  static RoleplayTurn? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final reply = readString(raw, 'reply');
    if (reply.isEmpty) return null;
    final understood = raw['understood'] != false;
    final corrected = readString(raw, 'corrected');
    final explanation = readString(raw, 'explanationTr');
    return RoleplayTurn(
      reply: reply,
      understood: understood,
      correction:
          understood && raw['hasError'] == true && corrected.isNotEmpty
          ? Correction(corrected: corrected, explanationTr: explanation)
          : null,
      goalReached: understood && raw['goalReached'] == true,
    );
  }
}

/// Gemini yanıtını [RoleplayTurn]'e çevirir; bozuksa null.
RoleplayTurn? parseRoleplayResponse(String responseBody) {
  final text = extractModelText(responseBody);
  if (text == null) return null;
  try {
    return RoleplayTurn.tryParse(jsonDecode(stripCodeFence(text)));
  } catch (_) {
    return null;
  }
}

// --- Kayıtlar ----------------------------------------------------------------

/// Sohbetin XP'si sayılması için gereken en az öğrenci mesajı.
const roleplayMinMessages = 4;

/// Tamamlanan sohbetin XP'si; görev de başarıldıysa bonus.
int roleplayXp({required bool goalReached}) => goalReached ? 25 : 15;

/// Rol yapma kayıtları (SharedPreferences, `roleplay_` önekli).
class RoleplayRecords {
  const RoleplayRecords({
    this.completed = 0,
    this.xp = 0,
    this.goalScenarios = const {},
  });

  static const completedKey = 'roleplay_completed';
  static const xpKey = 'roleplay_xp';
  static const goalsKey = 'roleplay_goals';

  /// XP kazandıran (yeterince uzun) sohbet sayısı.
  final int completed;
  final int xp;

  /// Görevi en az bir kez başarılan senaryolar.
  final Set<String> goalScenarios;

  factory RoleplayRecords.read(SharedPreferences prefs) => RoleplayRecords(
    completed: prefs.getInt(completedKey) ?? 0,
    xp: prefs.getInt(xpKey) ?? 0,
    goalScenarios: {...?prefs.getStringList(goalsKey)},
  );

  /// Biten sohbeti kaydeder ve kazanılan XP'yi döner (kısa sohbette 0).
  static Future<int> save(
    SharedPreferences prefs, {
    required String scenarioId,
    required int userMessages,
    required bool goalReached,
  }) async {
    if (userMessages < roleplayMinMessages) return 0;
    final old = RoleplayRecords.read(prefs);
    final xp = roleplayXp(goalReached: goalReached);
    await prefs.setInt(completedKey, old.completed + 1);
    await prefs.setInt(xpKey, old.xp + xp);
    if (goalReached) {
      await prefs.setStringList(goalsKey, [
        ...{...old.goalScenarios, scenarioId},
      ]);
    }
    return xp;
  }
}
