class NlpParser {
  static String deriveTitleFromNote(String note) {
    var text = note.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';

    final firstSentence = text.split(RegExp(r'[.!?]')).first.trim();
    var candidate = _normalizeTypos(firstSentence);

    for (final phrase in _leadingFillerPhrases) {
      if (candidate.startsWith('$phrase ')) {
        candidate = candidate.substring(phrase.length).trim();
        break;
      }
    }

    candidate = candidate
        .replaceFirst(RegExp(r'^(?:note|reminder|paalala)\s+(?:that|na)?\s*'), '')
        .replaceFirst(RegExp(r'^(?:um|uh|ah)\s+'), '')
        .trim();

    final words = candidate.split(RegExp(r'\s+'));
    if (words.length > 10) candidate = words.take(10).join(' ');
    if (candidate.length > 72) candidate = candidate.substring(0, 72).trimRight();
    if (candidate.isEmpty) return 'Voice note';
    return '${candidate[0].toUpperCase()}${candidate.substring(1)}';
  }

  static String detectLanguage(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-záéíóúñ\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    const tagalogWords = {
      'ako', 'ang', 'at', 'ay', 'bago', 'bukas', 'dapat', 'gawin', 'hindi',
      'ito', 'iyon', 'kailangan', 'ko', 'kong', 'mag', 'mga', 'mamaya', 'mo',
      'na', 'nang', 'ng', 'para', 'paalala', 'pagkatapos', 'sa', 'tapos',
      'tayo', 'yung', 'oras', 'minuto', 'linisin', 'hugasan', 'bumili',
    };
    const englishWords = {
      'a', 'after', 'and', 'before', 'buy', 'call', 'clean', 'do', 'for',
      'have', 'i', 'in', 'is', 'it', 'make', 'meeting', 'my', 'need', 'note',
      'of', 'on', 'remember', 'send', 'study', 'that', 'the', 'this', 'to',
      'tomorrow', 'want', 'with', 'write',
    };

    final tagalogScore = words.where(tagalogWords.contains).length;
    final englishScore = words.where(englishWords.contains).length;
    if (tagalogScore > 0 && englishScore > 0) return 'Taglish detected';
    if (tagalogScore > englishScore) return 'Tagalog detected';
    return 'English detected';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // English + Tagalog action verbs (root forms, mag- forms, -in/-an forms)
  // ─────────────────────────────────────────────────────────────────────────
  static final Set<String> actionVerbs = {
    // ── English ──
    'clean', 'wash', 'do', 'study', 'write', 'read', 'make', 'cook', 'buy',
    'get', 'fix', 'run', 'walk', 'exercise', 'prepare', 'send', 'email',
    'call', 'meeting', 'review', 'check', 'organize', 'tidy', 'sweep',
    'mop', 'vacuum', 'dust', 'sort', 'file', 'submit', 'create', 'update',
    'eat', 'drink', 'go', 'visit', 'wipe', 'plan', 'validate', 'search',
    'research', 'think', 'test', 'pay', 'order', 'bring', 'deliver', 'pick',
    'rest', 'sleep', 'shower', 'bathe',

    // ── Tagalog — Household / Cleaning ──
    'linis', 'maglinis', 'naglinis', 'linisin', 'linisan',
    'hugas', 'maghugas', 'naghugas', 'hugasan', 'hugasin',
    'laba', 'maglaba', 'naglaba', 'labhan', 'labahan',
    'plantsa', 'magplantsa', 'plantsahin',
    'walis', 'magwalis', 'walisin', 'walisan',
    'punas', 'magpunas', 'punasin', 'punasan',
    'mopa', 'magmopa', 'mopahin',
    'ayos', 'mag-ayos', 'ayusin',
    'luto', 'magluto', 'lutuin', 'lutoin',
    'banlawan', 'magbanlaw',
    'basura', 'magbasura', 'basurahin', 'itapon',

    // ── Tagalog — Study / Work ──
    'aral', 'mag-aral', 'aralin', 'aralan',
    'sulat', 'magsulat', 'sulatin',
    'basa', 'magbasa', 'basahin', 'basahan',
    'gawa', 'gumawa', 'gawin',
    'tapos', 'magtapos', 'tapusin',
    'simula', 'magsimula', 'simulan',
    'tsek', 'mag-tsek', 'tsekihin',
    'sumite', 'magsumite', 'isumite',
    'presenta', 'magpresenta', 'ipresenta',
    'plano', 'magplano', 'planuhan',
    'organisa', 'mag-organisa', 'organisahin',
    'kumpletuhin', 'pag-aralan', 'imbestigahin',

    // ── Tagalog — Communication ──
    'tumawag', 'magtawag', 'tawagan',
    'makipagkita', 'makita',
    'bumisita', 'bisitahin',
    'pumunta', 'magpunta', 'puntahan',
    'sunduin', 'suduhin', 'ihatid',
    'iulat', 'mag-ulat',
    'makipag-usap',

    // ── Tagalog — Shopping / Errands ──
    'bilhi', 'bumili', 'bilhin',
    'kuha', 'kumuha', 'kunin',
    'bayad', 'magbayad', 'bayaran',
    'ipadala', 'magpadala',
    'magdala', 'dalhin',

    // ── Tagalog — Health / Self-care ──
    'kumain', 'kainin',
    'uminom', 'inumin',
    'mag-ehersisyo', 'lumakad', 'lakarin',
    'tumakbo', 'matulog', 'magpahinga',
    'maligo',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // English + Tagalog leading filler phrases (stripped before parsing)
  // ─────────────────────────────────────────────────────────────────────────
  static final List<String> _leadingFillerPhrases = [
    // ── English ──
    'you must do it', 'you need to do it', 'please remember to',
    'dont forget to', "don't forget to", 'make sure to', 'you must',
    'you need to', 'you have to', 'need to', 'have to', 'please',
    'remember to', 'better hurry', 'be quick', 'hurry up', 'so better hurry',
    'this task would take only', 'this task would take', 'would take only',
    'take only within', 'task would take only', 'i would', 'i will',
    'i want to', 'i need to', 'i should', 'i have to', 'i must be able to',
    'i must', 'i decide to', 'i try to', 'we should', 'we need to',
    'we must', 'we will', 'we have to', 'you should', 'you will',
    'he should', 'she should', 'they should', 'try to', 'attempt to',
    'decide to', 'start to', 'begin to', 'must be able to', 'be able to',

    // ── Tagalog — need / must ──
    'kailangan ko nang', 'kailangan ko na', 'kailangan ko talaga',
    'kailangan kong', 'kailangan ko', 'kailangan natin', 'kailangan nating',
    'kailangan niyang', 'kailangan nilang', 'kailangan namin',
    'kailangan', 'kelangan kong', 'kelangan ko', 'kelangan',

    // ── Tagalog — should / must ──
    'dapat na talaga', 'dapat na', 'dapat kong', 'dapat ko', 'dapat nating',
    'dapat niyang', 'dapat nilang', 'dapat namin', 'dapat mo', 'dapat',

    // ── Tagalog — don't forget ──
    'huwag mong kalimutan', 'huwag kalimutang', 'huwag kalimutan',
    'huwag makalimot na', 'huwag makalimot', 'hwag kalimutang', 'hwag makalimutan',

    // ── Tagalog — make sure ──
    'siguraduhing', 'siguraduhin na', 'siguraduhin', 'tiyakin na', 'tiyakin',

    // ── Tagalog — want / plan / intend ──
    'gusto ko pong', 'gusto kong', 'gusto nating', 'gusto ko',
    'plano kong', 'plano nating', 'plano namin', 'plano ko',
    'balak kong', 'balak nating', 'balak ko',
    'nais kong', 'nais nating', 'nais ko',
    'iminumungkahi', 'imungkahi na',

    // ── Tagalog — will do ──
    'gagawin ko na', 'gagawin ko', 'gagawin natin', 'gagawin namin',
    'gagawin', 'gawin ko na', 'gawin na',

    // ── Tagalog — can / maybe ──
    'baka pwede naman', 'baka pwede', 'pwede ba', 'pwede ko bang',
    'puwede ba', 'puwede kong', 'baka naman', 'baka',

    // ── Tagalog — try ──
    'subukan mong', 'subukan ko', 'subukang', 'sumubok ng', 'sumubok',

    // ── Tagalog — remember / note ──
    'alalahanin na', 'alalahanin', 'tandaan na', 'tandaan',
    'i-remember na', 'i-remember', 'i-note na', 'i-note',

    // ── Tagalog — think ──
    'isipin na', 'isipin', 'pag-isipan na', 'pag-isipan',

    // ── Tagalog — do it now ──
    'gawin ko na', 'gawin na', 'gawin',
    'tapusin ko na', 'tapusin na',
    'simulan ko na', 'simulan na', 'simulan',
    'umpisa na', 'mag-umpisa na', 'magsimula na',
    'ayusin ko na', 'ayusin na',

    // ── Tagalog — check ──
    'i-check na', 'i-check', 'tingnan na', 'tingnan',
    'alagaan na', 'alagaan',

    // ── Tagalog — hurry ──
    'dali-dali na', 'dali-dali', 'magmadali na', 'magmadali',
    'mabilis lang', 'mabilis',

    // ── Tagalog — already / go ahead ──
    'puwede nang', 'puwede na', 'dapat na',

    // ── Taglish ──
    'i-start na', 'i-start', 'i-finish na', 'i-finish',
    'i-complete na', 'i-complete',
    'mag-focus na', 'mag-focus',
    'mag-concentrate na', 'mag-concentrate',
    'i-submit na', 'i-submit',
    'i-send na', 'i-send',
    'i-save na', 'i-save',
    'i-update na', 'i-update',
    'i-review na', 'i-review',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Transition words (used to split sentences into subtask steps)
  // ─────────────────────────────────────────────────────────────────────────
  static final List<String> _transitionWords = [
    // ── English ──
    'and then', 'after that', 'followed by', 'afterwards', 'firstly',
    'secondly', 'lastly', 'first', 'next', 'then', 'finally',

    // ── Tagalog — ordinal / sequence ──
    'una sa lahat', 'una',
    'pangalawa', 'ikalawa',
    'pangatlo', 'ikatlo',
    'pang-apat', 'ikaapat',
    'panglima', 'ikalima',
    'panghuli', 'sa huli', 'huli',

    // ── Tagalog — connectors ──
    'pagkatapos nito ay', 'pagkatapos nun', 'pagkatapos nito', 'pagkatapos',
    'at saka naman', 'at saka', 'saka naman', 'saka',
    'tapos na', 'tapos',
    'kasunod nito', 'kasunod',
    'bago ang', 'bago',
    'habang ginagawa', 'habang',
    'samantala',
    'bukod pa rito', 'bukod dito',
    'gayundin', 'gayunpaman',
    'dagdag pa rito', 'dagdag pa',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Tagalog number words → digits (used for alas- and duration parsing)
  // ─────────────────────────────────────────────────────────────────────────
  static final Map<String, int> _tagalogNumbers = {
    'isa': 1, 'dalawa': 2, 'tatlo': 3, 'apat': 4, 'lima': 5,
    'anim': 6, 'pito': 7, 'walo': 8, 'siyam': 9, 'sampu': 10,
    'onse': 11, 'dose': 12, 'labintatlo': 13, 'labing-tatlo': 13,
    'labinapat': 14, 'labing-apat': 14, 'labinlima': 15, 'labing-lima': 15,
    'labinganim': 16, 'labing-anim': 16,
    'labingpito': 17, 'labing-pito': 17, 'labingwalo': 18, 'labing-walo': 18,
    'labingsiyam': 19, 'labing-siyam': 19, 'dalawampu': 20,
    'tatlumpu': 30, 'tatlumpung': 30,
    'apatnapu': 40, 'apatnapung': 40,
    'limampu': 50, 'limampung': 50,
    'animnapu': 60, 'animnapung': 60,
    // composed ordinals for duration
    'sampung': 10, 'labinlimang': 15, 'dalawampung': 20,
    'isang': 1, 'dalawang': 2, 'tatlong': 3, 'apat na': 4,
    'limang': 5, 'animang': 6, 'pitong': 7, 'walong': 8, 'siyam na': 9,
  };

  // alas- (Spanish-Tagalog o'clock words) → 24h hour integer
  static final Map<String, int> _alasWords = {
    'isa': 1, 'dos': 2, 'tres': 3, 'kwatro': 4, 'kwato': 4,
    'singko': 5, 'sais': 6, 'siyete': 7, 'otso': 8, 'nuwebe': 9,
    'diyes': 10, 'onse': 11, 'dose': 12,
  };

  // ─────────────────────────────────────────────────────────────────────────
  // parseDeadline — English + Tagalog
  // ─────────────────────────────────────────────────────────────────────────
  static String? parseDeadline(String text) {
    if (text.isEmpty) return null;
    final lower = _normalizeTypos(text);

    // 1. English & Taglish: "start / start ako around / start at / before / by / at / until / due / around / ng / sa … HH:MM"
    final enTimeRegex = RegExp(
      r'(?:before|by|at|until|startTime|deadline|finish\s+by|complete\s+by|due\s+at|due\s+by|due|start\s+ako\s+around|start\s+ako\s+at|start\s+ako\s+ng|start\s+around|start\s+at|start\s+ng|starts\s+at|starts\s+around|starts|start|mag-start\s+ng|mag-start|magsimula\s+ng|magsimula|simulan\s+ng|simulan|around|about|limit|ng|sa)\s*([0-2]?\d)(?::(\d{2}))?\s*(am|pm|ng\s+hapon|ng\s+gabi|ng\s+umaga|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening)?',
      caseSensitive: false,
    );
    final enMatch = enTimeRegex.firstMatch(lower);
    if (enMatch != null) {
      return _buildTimeString(enMatch.group(1), enMatch.group(2), enMatch.group(3));
    }

    // 2. Tagalog — alas- o'clock (e.g. "alas-tres", "alas-singko ng hapon")
    final alasRegex = RegExp(
      r'alas[-\s]?(\w+)(?:\s*(ng\s+hapon|ng\s+gabi|ng\s+umaga|pm|am|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening))?',
      caseSensitive: false,
    );
    final alasMatch = alasRegex.firstMatch(lower);
    if (alasMatch != null) {
      final word = alasMatch.group(1)?.toLowerCase() ?? '';
      final suffix = alasMatch.group(2)?.toLowerCase() ?? '';
      final hour = _alasWords[word];
      if (hour != null) {
        int h = hour;
        if ((suffix.contains('hapon') || suffix.contains('gabi') || suffix.contains('pm') || suffix.contains('afternoon') || suffix.contains('evening')) && h < 12) h += 12;
        if ((suffix.contains('umaga') || suffix.contains('am') || suffix.contains('morning')) && h == 12) h = 0;
        return '${h.toString().padLeft(2, '0')}:00';
      }
    }

    // 3. Tagalog — mag- + digit (e.g. "mag-3 pm", "mag-alas tres")
    final magDigitRegex = RegExp(
      r'mag[-\s]([0-2]?\d)(?::(\d{2}))?\s*(am|pm|ng\s+hapon|ng\s+gabi|ng\s+umaga|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening)?',
      caseSensitive: false,
    );
    final magDigitMatch = magDigitRegex.firstMatch(lower);
    if (magDigitMatch != null) {
      final suffix = magDigitMatch.group(3)?.toLowerCase() ?? '';
      return _buildTimeString(
        magDigitMatch.group(1), magDigitMatch.group(2),
        (suffix.contains('hapon') || suffix.contains('gabi') || suffix.contains('afternoon') || suffix.contains('evening')) ? 'pm'
            : (suffix.contains('umaga') || suffix.contains('morning')) ? 'am' : magDigitMatch.group(3),
      );
    }

    // 4. Tagalog keywords + HH:MM (bago, hanggang, tapusin bago, dapat matapos, sa oras ng…)
    final tlStartTimeRegex = RegExp(
      r'(?:bago\s+mag|bago|hanggang\s+sa|hanggang|tapusin\s+bago|tapusin\s+ng|tapusin|dapat\s+matapos|dapat\s+tapusin|dapat\s+itapos|itapos\s+bago|matapos\s+ng|matapos|sa\s+oras\s+ng|pagsapit\s+ng|pag-dating\s+ng|takdang\s+oras|takda|mamaya\s+ng|bago\s+ang)\s*([0-2]?\d)(?::(\d{2}))?\s*(am|pm|ng\s+hapon|ng\s+gabi|ng\s+umaga|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening)?',
      caseSensitive: false,
    );
    final tlMatch = tlStartTimeRegex.firstMatch(lower);
    if (tlMatch != null) {
      final suffix = tlMatch.group(3)?.toLowerCase() ?? '';
      return _buildTimeString(
        tlMatch.group(1), tlMatch.group(2),
        (suffix.contains('hapon') || suffix.contains('gabi') || suffix.contains('afternoon') || suffix.contains('evening')) ? 'pm'
            : (suffix.contains('umaga') || suffix.contains('morning')) ? 'am' : tlMatch.group(3),
      );
    }

    // 5. Named time-of-day → time segment
    if (RegExp(r'\b(ngayong\s+gabi|gabi)\b').hasMatch(lower)) return '20:00';
    if (RegExp(r'\b(ngayong\s+tanghali|tanghali)\b').hasMatch(lower)) return '12:00';
    if (RegExp(r'\b(ngayong\s+umaga|umaga)\b').hasMatch(lower)) return '08:00';
    if (RegExp(r'\b(ngayong\s+hapon|hapon)\b').hasMatch(lower)) return '15:00';

    // 6. Standalone HH:MM or HHam / HHpm
    final standaloneRegex = RegExp(r'\b([0-2]?\d)(?::(\d{2}))?\s*(am|pm|ng\s+hapon|ng\s+gabi|ng\s+umaga|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening)\b', caseSensitive: false);
    final standaloneMatch = standaloneRegex.firstMatch(lower);
    if (standaloneMatch != null) {
      return _buildTimeString(standaloneMatch.group(1), standaloneMatch.group(2), standaloneMatch.group(3));
    }

    // 7. Standalone HH:MM without am/pm
    final standaloneColonRegex = RegExp(r'\b([0-2]?\d):(\d{2})\b', caseSensitive: false);
    final standaloneColonMatch = standaloneColonRegex.firstMatch(lower);
    if (standaloneColonMatch != null) {
      return _buildTimeString(standaloneColonMatch.group(1), standaloneColonMatch.group(2), null);
    }

    return null;
  }

  static String? _buildTimeString(String? hourStr, String? minStr, String? ampm) {
    int hour = int.tryParse(hourStr ?? '') ?? -1;
    if (hour < 0) return null;
    final int minute = int.tryParse(minStr ?? '') ?? 0;
    final ap = ampm?.toLowerCase();
    if (ap != null) {
      if ((ap.contains('pm') || ap.contains('hapon') || ap.contains('gabi') || ap.contains('afternoon') || ap.contains('evening')) && hour < 12) hour += 12;
      if ((ap.contains('am') || ap.contains('umaga') || ap.contains('morning')) && hour == 12) hour = 0;
    } else {
      // Natural productivity assumption: 1 to 6 o'clock defaults to afternoon/evening (13:00 - 18:00)
      if (hour >= 1 && hour <= 6) {
        hour += 12;
      }
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // parseDuration — English + Tagalog
  // ─────────────────────────────────────────────────────────────────────────
  static int? parseDuration(String text) {
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    // 1. Tagalog word phrases
    if (RegExp(r'kalahating\s+oras').hasMatch(lower)) return 30;
    if (RegExp(r'isang\s+oras\s+at\s+kalahati').hasMatch(lower)) return 90;
    if (RegExp(r'dalawang\s+oras\s+at\s+kalahati').hasMatch(lower)) return 150;
    if (RegExp(r'ilang\s+minuto\s+lang|mabilis\s+lang|mabilis').hasMatch(lower)) return 5;

    // 2. Tagalog number words + unit (e.g. "tatlumpung minuto", "anim na oras", "isang oras")
    for (final entry in _tagalogNumbers.entries) {
      final n = entry.key;
      final val = entry.value;
      if (RegExp('\\b$n\\s*(?:na\\s+)?minuto').hasMatch(lower)) return val;
      if (RegExp('\\b$n\\s*(?:na\\s+)?oras').hasMatch(lower)) return val * 60;
    }

    // 3. Hours (e.g. "6 hours", "for 6 hours", "6 hrs", "6hr", "6 oras", "6 na oras")
    final hrRegex = RegExp(
      r'(?:within|take|last|around|about|for|duration\s+of|spending|max|sa\s+loob\s+ng|loob\s+ng|tatagal\s+ng|tumagal\s+ng|matatagalan\s+ng|magtatagal\s+ng|halos|mga)?\s*(\d+(?:\.\d+)?)\s*(?:hour|hours|hr|hrs|oras|na\s+oras)\b',
      caseSensitive: false,
    );
    final hrMatch = hrRegex.firstMatch(lower);
    if (hrMatch != null) {
      final hours = double.tryParse(hrMatch.group(1) ?? '') ?? 0;
      if (hours > 0) return (hours * 60).toInt();
    }

    // 4. Minutes (e.g. "45 mins", "within 30 minutes", "15 minuto")
    final minRegex = RegExp(
      r'(?:within|take|last|around|about|for|duration\s+of|spending|max|sa\s+loob\s+ng|loob\s+ng|tatagal\s+ng|tumagal\s+ng|matatagalan\s+ng|magtatagal\s+ng|halos|mga|hindi\s+bababa\s+sa)?\s*(\d+)\s*(?:minuto|minutos|minits|min|mins|minute|minutes)\b',
      caseSensitive: false,
    );
    final minMatch = minRegex.firstMatch(lower);
    if (minMatch != null) {
      final mins = int.tryParse(minMatch.group(1) ?? '') ?? 0;
      if (mins > 0) return mins;
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // parseSubtasks — English + Tagalog
  // ─────────────────────────────────────────────────────────────────────────
  static List<String> parseSubtasks(String text) {
    if (text.trim().isEmpty) return [];

    final rawText = text.trim();

    // 1. Multiline text: each non-empty line is a subtask candidate
    if (rawText.contains('\n') || rawText.contains('\r')) {
      final lines = rawText.split(RegExp(r'\r?\n'));
      final List<String> multilineSteps = [];
      for (var line in lines) {
        var cleaned = _cleanClauseText(line);
        if (cleaned.isEmpty || _isPureScheduleClause(cleaned)) continue;
        cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
        if (!multilineSteps.contains(cleaned)) {
          multilineSteps.add(cleaned);
        }
      }
      if (multilineSteps.isNotEmpty) return multilineSteps;
    }

    // 2. Prose text: split by periods, sentence terminators, and transition words
    final sentenceSplitRegex = RegExp(
      r'(?:[.!?]+(?:\s+|$))|'
      r'(?:;+(?:\s+|$))|'
      r'(?:[,;]?\s*\b(?:'
      r'and\s+then|then|next|after\s+that|afterwards|followed\s+by'
      r'|pagkatapos\s+nito\s+ay|pagkatapos\s+nun|pagkatapos\s+nito|pagkatapos'
      r'|at\s+saka\s+naman|at\s+saka|saka\s+naman|saka'
      r'|tapos\s+na|tapos'
      r'|kasunod\s+nito|kasunod'
      r'|samantala|gayundin|gayunpaman'
      r'|bukod\s+pa\s+rito|bukod\s+dito'
      r'|dagdag\s+pa\s+rito|dagdag\s+pa'
      r')\b)',
      caseSensitive: false,
    );

    final rawClauses = rawText.split(sentenceSplitRegex);

    final List<String> steps = [];
    for (var clause in rawClauses) {
      var cleaned = _cleanClauseText(clause);
      if (cleaned.isEmpty || _isPureScheduleClause(cleaned)) continue;
      // Capitalize first letter
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
      if (!steps.contains(cleaned)) {
        steps.add(cleaned);
      }
    }

    if (steps.isNotEmpty) return steps;

    return [];
  }

  static String _cleanClauseText(String text) {
    var cleaned = text.trim();

    // Strip leading bullet/number markers (e.g. "1. ", "- ", "* ", "• ")
    if (cleaned.startsWith('-') || cleaned.startsWith('*') || cleaned.startsWith('•')) {
      cleaned = cleaned.substring(1).trim();
    } else {
      final match = RegExp(r'^\d+[\.\/\)]\s*').firstMatch(cleaned);
      if (match != null) cleaned = cleaned.substring(match.end).trim();
    }

    // Iteratively strip leading filler phrases & transition words
    bool changed = true;
    while (changed) {
      changed = false;
      final lower = cleaned.toLowerCase();
      for (var phrase in _leadingFillerPhrases) {
        if (lower.startsWith('$phrase ') || lower == phrase) {
          cleaned = cleaned.substring(phrase.length).trim();
          changed = true;
          break;
        }
      }
      for (var word in _transitionWords) {
        if (lower.startsWith('$word ') || lower == word) {
          cleaned = cleaned.substring(word.length).trim();
          changed = true;
          break;
        }
      }
      cleaned = cleaned.replaceAll(RegExp(r'^[,.\s\-*•:;]+'), '');
    }

    // Strip trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[,.\s:;]+$'), '');
    return cleaned;
  }

  static bool _isPureScheduleClause(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return true;
    if (lower.length < 3) return true;

    // Pure start / due / deadline statements (e.g. "start ako around 5:30", "start at 5:30 pm", "around 5:30", "due at 4pm")
    final schedulePattern = RegExp(
      r'^(?:(?:ill|i\s+will|i\s+ll|ako\s+ay|mag)?\s*(?:start|starts|mag-start|magsimula|simula|simulan|due|deadline(?:\s+is)?|before|by|at|until|around|about|bago|hanggang|sa\s+oras\s+ng)\s*(?:ako\s+)?(?:around|about|at|by|ng|sa)?\s*)?'
      r'(?:alas[-\s]?\w+|[0-2]?\d(?::\d{2})?\s*(?:am|pm|ng\s+hapon|ng\s+umaga|ng\s+gabi)?)\s*$',
      caseSensitive: false,
    );
    if (schedulePattern.hasMatch(lower)) return true;

    // Pure standalone duration statement (e.g. "for 6 hours", "within 30 mins", "duration is 2 hours")
    final pureDurationPattern = RegExp(
      r'^(?:for|take|within|duration(?:\s+is)?|spending|magtatagal\s+ng|tatagal\s+ng)?\s*\d+(?:\.\d+)?\s*(?:min|mins|minute|minutes|minuto|hour|hours|hr|hrs|oras)\s*$',
      caseSensitive: false,
    );
    if (pureDurationPattern.hasMatch(lower)) return true;

    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // generateAiSubsteps — English + Tagalog keywords
  // ─────────────────────────────────────────────────────────────────────────
  static List<String> generateAiSubsteps(String title) {
    final lower = title.toLowerCase();

    // Report / Writing
    if (_matchesAny(lower, ['report', 'write', 'doc', 'paper', 'essay', 'thesis',
        'ulat', 'sulatin', 'papel', 'sanaysay'])) {
      return ['Open laptop', 'Open document editor', 'Write the title & outline'];
    }

    // Dishes / Laundry
    if (_matchesAny(lower, ['dish', 'wash', 'sink', 'laundry', 'clothes',
        'pinggan', 'hugasan', 'labahan', 'laba', 'damit', 'basahan'])) {
      return ['Turn on water', 'Put soap on sponge', 'Wash first item'];
    }

    // Study
    if (_matchesAny(lower, ['study', 'math', 'homework', 'read', 'learn', 'exam', 'quiz',
        'mag-aral', 'aralin', 'takdang aralin', 'pagsusulit', 'pagbabasa'])) {
      return ['Clear your workspace', 'Open textbook or document', 'Read first page or solve first problem'];
    }

    // Exercise
    if (_matchesAny(lower, ['exercise', 'run', 'walk', 'gym', 'workout',
        'mag-ehersisyo', 'lumakad', 'tumakbo', 'ehersisyo'])) {
      return ['Put on sports shoes', 'Grab a water bottle', 'Start warm-up stretch'];
    }

    // Cleaning
    if (_matchesAny(lower, ['clean', 'tidy', 'room', 'sweep', 'mop',
        'maglinis', 'linisin', 'silid', 'bahay', 'sala', 'kusina', 'banyo', 'walis'])) {
      return ['Pick up 3 items from floor', 'Tidy workspace desk', 'Wipe down surfaces'];
    }

    // Cooking
    if (_matchesAny(lower, ['cook', 'dinner', 'lunch', 'breakfast', 'meal', 'food',
        'magluto', 'lutuin', 'kain', 'almusal', 'tanghalian', 'hapunan', 'merienda'])) {
      return ['Wash your hands', 'Gather ingredients from fridge', 'Turn on stove or prep counter'];
    }

    // Communication
    if (_matchesAny(lower, ['email', 'message', 'reply', 'send', 'call',
        'mag-email', 'mag-text', 'mag-message', 'tumawag', 'tawagan'])) {
      return ['Open communication app', 'Find recipient or click Compose', 'Write the first sentence'];
    }

    // Bills / Payment
    if (_matchesAny(lower, ['pay', 'bill', 'payment', 'invoice',
        'magbayad', 'bayaran', 'bayad', 'bills', 'singil'])) {
      return ['Open banking app', 'Find the payee or bill', 'Confirm the amount and pay'];
    }

    // Shopping / Grocery
    if (_matchesAny(lower, ['buy', 'grocery', 'shop', 'store', 'market',
        'bumili', 'bilhin', 'palengke', 'tindahan', 'pamimili', 'grocery'])) {
      return ['Write your shopping list', 'Go to the store', 'Check items off the list'];
    }

    // Medical / Doctor
    if (_matchesAny(lower, ['doctor', 'clinic', 'hospital', 'check-up', 'checkup',
        'doktor', 'klinika', 'ospital', 'mag-check-up'])) {
      return ['Prepare your documents/ID', 'Travel to the clinic', 'Wait for your consultation'];
    }

    // Meeting / Presentation
    if (_matchesAny(lower, ['meeting', 'present', 'conference', 'kumperensya',
        'pulong', 'presentation', 'mag-meeting'])) {
      return ['Review the agenda', 'Set up screen or camera', 'Open meeting app and join'];
    }

    // Generic fallback
    return ['Clear your workspace', 'Get necessary tools/tabs ready', 'Focus for just 2 minutes'];
  }

  static bool _matchesAny(String lower, List<String> keywords) {
    for (final kw in keywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // parseRepeatUntil — parses end-date phrases for recurring tasks
  // Returns the last date the task should repeat on.
  // ─────────────────────────────────────────────────────────────────────────
  static DateTime? parseRepeatUntil(String text) {
    if (text.isEmpty) return null;
    final lower = _normalizeTypos(text);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── "next next week" / "the week after next" → 14 days from next Monday ──
    if (RegExp(r'\b(next\s+next\s+week|week\s+after\s+next|susunod\s+na\s+susunod\s+na\s+linggo)\b').hasMatch(lower)) {
      final daysToMonday = (8 - today.weekday) % 7 == 0 ? 7 : (8 - today.weekday) % 7;
      return today.add(Duration(days: daysToMonday + 13)); // end of that week (Sunday)
    }

    // ── "next week" → end of next week (Sunday) ──
    if (RegExp(r'\b(next\s+week|susunod\s+na\s+linggo|sa\s+susunod\s+na\s+linggo)\b').hasMatch(lower)) {
      final daysToMonday = (8 - today.weekday) % 7 == 0 ? 7 : (8 - today.weekday) % 7;
      return today.add(Duration(days: daysToMonday + 6));
    }

    // ── "end of month" / "end of this month" ──
    if (RegExp(r'\bend\s+of\s+(this\s+)?month\b|katapusan\s+ng\s+(buwan|buwang\s+ito)\b').hasMatch(lower)) {
      return DateTime(today.year, today.month + 1, 0); // last day of current month
    }

    // ── "end of next month" ──
    if (RegExp(r'\bend\s+of\s+next\s+month\b|katapusan\s+ng\s+susunod\s+na\s+buwan\b').hasMatch(lower)) {
      return DateTime(today.year, today.month + 2, 0);
    }

    // ── "for N weeks" or "N weeks" ──
    final weeksMatch = RegExp(r'(?:for\s+)?(\d+)\s+weeks?\b', caseSensitive: false).firstMatch(lower);
    if (weeksMatch != null) {
      final weeks = int.tryParse(weeksMatch.group(1) ?? '') ?? 1;
      return today.add(Duration(days: weeks * 7));
    }

    // ── "for N months" or "N months" ──
    final monthsMatch = RegExp(r'(?:for\s+)?(\d+)\s+months?\b', caseSensitive: false).firstMatch(lower);
    if (monthsMatch != null) {
      final months = int.tryParse(monthsMatch.group(1) ?? '') ?? 1;
      return DateTime(today.year, today.month + months, today.day);
    }

    // ── "for N days" ──
    final daysMatch = RegExp(r'\bfor\s+(\d+)\s+days?\b', caseSensitive: false).firstMatch(lower);
    if (daysMatch != null) {
      final days = int.tryParse(daysMatch.group(1) ?? '') ?? 1;
      return today.add(Duration(days: days));
    }

    // ── "until/til/hanggang [month name] [day]" e.g. "until Sept 30" ──
    const monthNames = {
      'jan': 1, 'january': 1, 'enero': 1,
      'feb': 2, 'february': 2, 'pebrero': 2,
      'mar': 3, 'march': 3, 'marso': 3,
      'apr': 4, 'april': 4, 'abril': 4,
      'may': 5, 'mayo': 5,
      'jun': 6, 'june': 6, 'hunyo': 6,
      'jul': 7, 'july': 7, 'hulyo': 7,
      'aug': 8, 'august': 8, 'agosto': 8,
      'sep': 9, 'sept': 9, 'september': 9, 'setyembre': 9,
      'oct': 10, 'october': 10, 'oktubre': 10,
      'nov': 11, 'november': 11, 'nobyembre': 11,
      'dec': 12, 'december': 12, 'disyembre': 12,
    };

    final monthPattern = monthNames.keys.join('|');
    final dateRegex = RegExp(
      r'(?:until|till|til|by|hanggang|bago\s+mag)\s+(' + monthPattern + r')\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s*,?\s*(\d{4}))?',
      caseSensitive: false,
    );
    final dateMatch = dateRegex.firstMatch(lower);
    if (dateMatch != null) {
      final monthStr = dateMatch.group(1)!.toLowerCase();
      final day = int.tryParse(dateMatch.group(2) ?? '') ?? 1;
      final yearStr = dateMatch.group(3);
      final monthNum = monthNames[monthStr] ?? 1;
      int year = yearStr != null ? (int.tryParse(yearStr) ?? today.year) : today.year;
      // If the date has already passed this year, use next year
      final candidate = DateTime(year, monthNum, day);
      if (candidate.isBefore(today) && yearStr == null) {
        year = today.year + 1;
      }
      return DateTime(year, monthNum, day);
    }

    // ── "until [day] [month name]" e.g. "until 30 Sept" ──
    final dateRegex2 = RegExp(
      r'(?:until|till|til|by|hanggang)\s+(\d{1,2})(?:st|nd|rd|th)?\s+(' + monthPattern + r')(?:\s*,?\s*(\d{4}))?',
      caseSensitive: false,
    );
    final dateMatch2 = dateRegex2.firstMatch(lower);
    if (dateMatch2 != null) {
      final day = int.tryParse(dateMatch2.group(1) ?? '') ?? 1;
      final monthStr = dateMatch2.group(2)!.toLowerCase();
      final yearStr = dateMatch2.group(3);
      final monthNum = monthNames[monthStr] ?? 1;
      int year = yearStr != null ? (int.tryParse(yearStr) ?? today.year) : today.year;
      final candidate = DateTime(year, monthNum, day);
      if (candidate.isBefore(today) && yearStr == null) year = today.year + 1;
      return DateTime(year, monthNum, day);
    }

    // ── "until/til/hanggang [month name]" (whole month e.g. "til november" -> last day of that month) ──
    final wholeMonthRegex = RegExp(
      r'(?:until|till|til|by|hanggang|bago\s+mag)\s+(' + monthPattern + r')(?:\s+(\d{4}))?',
      caseSensitive: false,
    );
    final wholeMonthMatch = wholeMonthRegex.firstMatch(lower);
    if (wholeMonthMatch != null) {
      final monthStr = wholeMonthMatch.group(1)!.toLowerCase();
      final monthNum = monthNames[monthStr] ?? 1;
      final yearStr = wholeMonthMatch.group(2);
      int year = yearStr != null ? (int.tryParse(yearStr) ?? today.year) : today.year;
      // Last day of that month
      DateTime candidate = DateTime(year, monthNum + 1, 0);
      if (candidate.isBefore(today) && yearStr == null) {
        year = today.year + 1;
        candidate = DateTime(year, monthNum + 1, 0);
      }
      return candidate;
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // parseRepeatDays — English + Tagalog
  // ─────────────────────────────────────────────────────────────────────────
  static List<String> parseRepeatDays(String text) {
    if (text.isEmpty) return [];
    final lower = _normalizeTypos(text);

    // "every day" shortcuts
    if (RegExp(r'\b(araw-araw|bawat\s+araw|tuwing\s+araw|everyday|every\s+day|daily)\b').hasMatch(lower)) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }
    if (RegExp(r'\b(weekdays|araw\s+ng\s+trabaho|sa\s+weekdays)\b').hasMatch(lower)) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    }
    if (RegExp(r'\b(weekends|tuwing\s+weekend|sa\s+weekends)\b').hasMatch(lower)) {
      return ['Sat', 'Sun'];
    }

    final Map<String, List<String>> dayMappings = {
      'Mon': ['monday', 'mon', 'lunes', 'lun'],
      'Tue': ['tuesday', 'tue', 'martes', 'mar'],
      'Wed': ['wednesday', 'wed', 'miyerkules', 'miyerkoles', 'miy', 'mier'],
      'Thu': ['thursday', 'thu', 'huwebes', 'huw'],
      'Fri': ['friday', 'fri', 'biyernes', 'biy', 'bier'],
      'Sat': ['saturday', 'sat', 'sabado', 'sab'],
      'Sun': ['sunday', 'sun', 'linggo', 'lin'],
    };

    final List<String> days = [];
    for (var entry in dayMappings.entries) {
      for (var keyword in entry.value) {
        if (RegExp('\\b${RegExp.escape(keyword)}\\b').hasMatch(lower)) {
          if (!days.contains(entry.key)) days.add(entry.key);
          break;
        }
      }
    }
    return days;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _normalizeTypos — English + Tagalog voice-to-text normalization
  // ─────────────────────────────────────────────────────────────────────────
  static String _normalizeTypos(String text) {
    var lower = text.toLowerCase();

    // ── Tagalog honorifics / hedges / filler particles (strip entirely) ──
    lower = lower
        .replaceAll(RegExp(r'\bpo\s+naman\b'), '')
        .replaceAll(RegExp(r'\bpo\b'), '')
        .replaceAll(RegExp(r'\bkasi\b'), '')
        .replaceAll(RegExp(r'\beh\b'), '')
        .replaceAll(RegExp(r'\bnaman\b'), '')
        .replaceAll(RegExp(r'\btalaga\b'), '')
        .replaceAll(RegExp(r'\bnga\b'), '')
        .replaceAll(RegExp(r'\bdin\b'), '')
        .replaceAll(RegExp(r'\brin\b'), '')
        .replaceAll(RegExp(r'\bdaw\b'), '')
        .replaceAll(RegExp(r'\braw\b'), '')
        .replaceAll(RegExp(r'\bparang\b'), '')
        .replaceAll(RegExp(r'\bsiguro\b'), '')
        .replaceAll(RegExp(r'\bbaka\s+naman\b'), '')
        .replaceAll(RegExp(r'\btulad\s+ng\b'), '')
        .replaceAll(RegExp(r'\bhalimbawa\b'), '');

    // ── alas- hyphen normalization ──
    lower = lower.replaceAll(RegExp(r'\balas\s+'), 'alas-');

    // ── mag- spacing normalization ──
    lower = lower.replaceAll(RegExp(r'\bmag\s+(\d)'), 'mag-\$1');

    // ── pagkatapos spelling variants ──
    lower = lower
        .replaceAll(RegExp(r'\bpag\s+tapos\b'), 'pagkatapos')
        .replaceAll(RegExp(r'\bpag\s+katapos\b'), 'pagkatapos')
        .replaceAll(RegExp(r'\bpagka\s+tapos\b'), 'pagkatapos')
        .replaceAll(RegExp(r'\bat\s+saka\s+naman\b'), 'at saka');

    // ── Tagalog duration unit normalizations ──
    lower = lower
        .replaceAll(RegExp(r'\bminits\b'), 'minuto')
        .replaceAll(RegExp(r'\boras\s+na\b'), 'oras');

    // ── English time-of-day ──
    lower = lower
        .replaceAll(RegExp(r'\bmn\b'), 'am')
        .replaceAll(RegExp(r'\bnn\b'), 'pm')
        .replaceAll(RegExp(r'\bmidnight\b'), '12:00 am')
        .replaceAll(RegExp(r'\bnoon\b'), '12:00 pm');

    // ── English typo corrections ──
    final replacements = {
      r'\b(?:befor|befoer)\b': 'before',
      r'\bunt+il+\b': 'until',
      r'\b(?:deadlines|deadline|dedline|dealine)\b': 'startTime',
      r'\b(?:finish|fnish|finsh)\b': 'finish',
      r'\b(?:complete|compleat|compleet)\b': 'complete',
      r'\b(?:around|arond)\b': 'around',
      r'\b(?:about|abut)\b': 'about',
      r'\blim+it\b': 'limit',
      r'\b(?:minutes|minute|minits|mins)\b': 'minutes',
      r'\b(?:hours|hour|huors|horus|hrs)\b': 'hours',
      r'\b(?:today|todaey)\b': 'today',
      r'\b(?:tomorrow|tomorow|tommorow)\b': 'tomorrow',
      r'\b(?:monday|mondy)\b': 'monday',
      r'\b(?:tuesday|tuesdy)\b': 'tuesday',
      r'\b(?:wednesday|wednesdy)\b': 'wednesday',
      r'\b(?:thursday|thursdy)\b': 'thursday',
      r'\b(?:friday|fridy)\b': 'friday',
      r'\b(?:saturday|saturdy)\b': 'saturday',
      r'\b(?:sunday|sundy)\b': 'sunday',
      r'\b(?:clean|cleen)\b': 'clean',
      r'\b(?:study|stduey)\b': 'study',
      r'\b(?:prepare|prepar)\b': 'prepare',
      r'\b(?:review|reveiw)\b': 'review',
      r'\b(?:exercise|execise|excercise)\b': 'exercise',
      r'\b(?:organize|organise)\b': 'organize',
    };

    replacements.forEach((pattern, replacement) {
      lower = lower.replaceAll(RegExp(pattern), replacement);
    });

    return lower;
  }
}
