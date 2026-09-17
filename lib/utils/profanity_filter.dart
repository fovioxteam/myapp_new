class ProfanityFilter {
  // Список баз/корней плохих слов (EN & RU)
  static final List<String> _badWords = [
    // English
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'cunt', 'bastard', 'crap',
    // Russian (основные корни и матерные слова)
    'хуй', 'хуе', 'хуи', 'хуя', 'пизд', 'бля', 'блят', 'еб', 'ёб', 'заеб', 
    'пидор', 'гандон', 'мудак', 'сука', 'долбоеб', 'сучк'
  ];

  /// Проверка текста на наличие мата
  static bool containsProfanity(String text) {
    if (text.trim().isEmpty) return false;

    // Нормализация: приводим к нижнему регистру и заменяем популярные спецсимволы-заменители
    String normalized = text.toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll('\$', 's') // 👈 Экранируем символ $
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('!', 'i');

    for (var badWord in _badWords) {
      if (normalized.contains(badWord)) {
        return true;
      }
    }
    return false;
  }
}