import 'package:flutter/widgets.dart';

import '../settings.dart';

/// Languages the app ships strings for.
///
/// Scope note: **every safety-critical surface is translated** — the Get-help
/// screen (counselors, crisis lines, reporting), the disclaimers, navigation and
/// Settings. The embedded WebViews (newsletters, publications, calendars) are
/// the school's own pages and are rendered in whatever language those pages
/// use; the app cannot translate them.
enum AppLanguage {
  system('system', 'System default', 'Sistema'),
  english('en', 'English', 'English'),
  spanish('es', 'Español', 'Español'),
  chinese('zh', '简体中文', '中文'),
  tagalog('tl', 'Filipino', 'Filipino');

  const AppLanguage(this.code, this.nativeName, this.shortName);

  /// BCP-47 tag; [system] is resolved against the device locale.
  final String code;

  /// Name shown in the language picker, in that language.
  final String nativeName;

  /// Compact form for the app bar / chips.
  final String shortName;

  /// The language's own name plus how to say it in the other shipped
  /// languages, so the picker is usable by a student who cannot yet read
  /// English (e.g. "Español · Spanish · 西班牙语 · Espanyol").
  String get pluralLabel => switch (this) {
        AppLanguage.system => 'System · Sistema · 系统 · Sistema',
        AppLanguage.english => 'English · Inglés · 英语 · Ingles',
        AppLanguage.spanish => 'Español · Spanish · 西班牙语 · Espanyol',
        AppLanguage.chinese => '简体中文 · Chinese · Chino · Tsino',
        AppLanguage.tagalog => 'Filipino · Tagalog · 菲律宾语 · Filipino',
      };

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.system,
      );

  /// The concrete language tag to use for [deviceLocale].
  String resolve(Locale deviceLocale) {
    if (this != AppLanguage.system) return code;
    switch (deviceLocale.languageCode) {
      case 'es':
        return 'es';
      case 'zh':
        return 'zh';
      case 'tl':
      case 'fil':
        return 'tl';
      default:
        return 'en';
    }
  }
}

/// String catalogue.
///
/// Deliberately hand-rolled rather than generated: the app only needs a handful
/// of screens translated, there is no build-time code generation in this repo,
/// and a missing key falling back to English is the right failure mode for a
/// safety screen (never an empty label).
class AppStrings {
  const AppStrings(this.languageCode);

  /// Resolved BCP-47 code (`en`, `es`, `zh`, `tl`).
  final String languageCode;

  static AppStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return forTag(AppSettings.instance.language.resolve(locale));
  }

  static AppStrings forTag(String tag) => AppStrings(tag);

  /// Look up [key]; falls back to English, then to the key itself so a typo is
  /// visible in tests rather than silently blank.
  String operator [](String key) =>
      _catalog[languageCode]?[key] ?? _catalog['en']![key] ?? key;

  /// True when the catalogue for this language does not have [key] (used by
  /// tests to keep the four catalogues in sync).
  bool isMissing(String key) => !(_catalog[languageCode]?.containsKey(key) ?? false);

  /// Keys that must exist in every language: anything a student can be reading
  /// while in distress, plus the legal disclaimer.
  static List<String> get criticalKeys => _catalog['en']!
      .keys
      .where((k) => k.startsWith('help.') || k.startsWith('disclaimer.'))
      .toList(growable: false);

  static Map<String, Map<String, String>> get catalog => _catalog;
}

// ===========================================================================
// Catalogues
// ===========================================================================

const Map<String, Map<String, String>> _catalog = {
  // -------------------------------------------------------------------- English
  'en': {
    'app.title': 'Westview HS',
    'nav.schedule': 'Schedule',
    'nav.newsletters': 'Newsletters',
    'nav.publications': 'Publications',
    'nav.calendars': 'Calendar',
    'nav.getHelp': 'Get help',
    'common.call': 'Call',
    'common.text': 'Text',
    'common.website': 'Website',
    'common.close': 'Close',
    'common.cancel': 'Cancel',
    'common.openInBrowser': 'Open in browser',
    'common.copyNumber':
        'Copy this number',
    'sms.confirmTitle':
        'Send this text?',
    'sms.openApp':
        'Open Messages',
    'sms.editNote':
        'Your messaging app will open with this message ready to send. You can edit or add to it first.',

    'disclaimer.short':
        'Not a Poway Unified app. Not sponsored or endorsed by Poway Unified '
            'School District or Westview High School.',
    'disclaimer.title': 'This app is not part of Poway Unified',
    'disclaimer.plain':
        'In plain terms: Westview HS (WVAA) is a student-built companion app. '
            'Poway Unified School District and Westview High School did not '
            'make it, do not run it, and have not reviewed it. Anything shown '
            'here may be out of date or wrong — always confirm with the school '
            'office, your counselor, or the school website.',
    'disclaimer.crisis':
        'This app is not a crisis service and is not monitored. If you or '
            'someone else is in danger, call 911. In an emotional crisis, call '
            'or text 988.',
    'disclaimer.translationNote':
        'Translations of the disclaimer are provided to help you understand it. '
            'The official English and Spanish wording required by the district '
            'is the version that governs.',

    'help.title': 'Get help',
    'help.emergency.title': 'In immediate danger?',
    'help.emergency.body':
        'Call 911 now if you or someone else is about to be hurt, or you need '
            'help right this minute.',
    'help.emergency.call': 'Call 911',
    'help.emergency.note':
        'If you’re not sure whether it’s an emergency, call or text 988. '
            'Someone will answer and help you figure out next steps.',

    'help.counselor.title': 'Talk to a counselor at Westview',
    'help.counselor.body':
        'Counselors are in the Wolverine Center during the school day. You can '
            'drop in, ask a teacher to help you get there, or email your '
            'counselor directly — you don’t need to explain everything to make '
            'the appointment.',
    'help.counselor.callOffice': 'Call the office',
    'help.counselor.website': 'Counseling website',
    'help.counselor.find': 'Find your counselor',
    'help.counselor.byLast': 'By the first letter of your last name.',
    'help.counselor.career': 'College & career questions',
    'help.counselor.verified':
        'Staff and caseloads can change during the year. Check the school '
            'website or the counseling office if your name’s letter isn’t '
            'listed. (List checked November 2025.)',

    'help.crisis.title': 'Crisis lines — free, confidential, 24/7',
    'help.crisis.call': 'Call',
    'help.crisis.text': 'Text',
    'help.crisis.deaf':
        'Hard of hearing, or can’t speak on the phone? Every option below also '
            'works by text or online. 988 and the Crisis Text Line are '
            'text-first, and San Diego County’s line can be reached through a '
            'relay operator: dial 711.',

    'help.report.title': 'Report a safety concern',
    'help.report.body':
        'Worried about a classmate, a threat, a weapon, or something you saw '
            'online? Tell a trusted adult — a teacher, your counselor, a coach, '
            'or a parent. You can also report it anonymously:',
    'help.report.note':
        'You don’t have to be certain. Reports can be wrong and that’s okay — '
            'the people who check them are trained for it.',

    'help.about.title': 'About this app',

    'hotline.988.name': '988 Suicide & Crisis Lifeline',
    'hotline.988.desc':
        'Free, confidential support for anyone in emotional distress or '
            'suicidal crisis. Call or text any time, day or night.',
    'hotline.988.call': 'Call 988',
    'hotline.988.sms': 'Text 988',
    'hotline.sdaocl.name': 'San Diego Access & Crisis Line',
    'hotline.sdaocl.desc':
        'San Diego County’s 24/7 line for mental health and substance use '
            'crises, for you or someone you’re worried about. Free interpreters '
            'in 200+ languages. They can also send a Mobile Crisis Response '
            'Team.',
    'hotline.sdaocl.call': 'Call 1-888-724-7240',
    'hotline.crisistext.name': 'Crisis Text Line',
    'hotline.crisistext.desc':
        'Prefer typing to talking? Text a trained volunteer about anything '
            'that’s weighing on you. Free, 24/7, and confidential.',
    'hotline.crisistext.sms': 'Text HOME to 741741',
    'hotline.trevor.name': 'The Trevor Project',
    'hotline.trevor.desc':
        'Crisis and suicide-prevention support for LGBTQ+ young people, 24/7. '
            'You deserve to be taken seriously.',
    'hotline.trevor.call': 'Call 1-866-488-7386',
    'hotline.trevor.sms': 'Text START to 678678',
    'hotline.sandyhook.name': 'Say Something Anonymous Reporting',
    'hotline.sandyhook.desc':
        'Anonymous way to report threats, weapons, or someone who may be in '
            'danger — answered by crisis counselors. Good for “I’m worried '
            'about a classmate,” not just emergencies.',
    'hotline.sandyhook.call': 'Call 1-844-5-SAYNOW',
    'hotline.pusdtip.name': 'PUSD “See Something, Say Something” Tip Line',
    'hotline.pusdtip.desc':
        'Poway Unified’s 24-hour anonymous tip line, monitored by law '
            'enforcement, for school threats and safety concerns. The number '
            'is on the back of your student ID.',
    'hotline.pusdtip.call': 'Call 1-844-PUSD-TIP',

    'settings.title': 'Settings',
    'settings.safety': 'Safety',
    'settings.getHelp': 'Get help now',
    'settings.getHelpSub':
        'Westview counselors, crisis lines and hotlines, and how to report a '
            'safety concern. Works offline.',
    'settings.quickExit': 'Quick exit',
    'settings.quickExitSub':
        'Long-press the Help button to leave the app immediately. Nothing you '
            'looked at stays on screen.',
    'settings.hideRecents': 'Hide preview in app switcher',
    'settings.hideRecentsSub':
        'Stops the app’s last screen from showing in your recent-apps list '
            '(Android).',
    'settings.language': 'Language',
    'settings.languageSub': 'Applies to Help, Settings and navigation.',
    'settings.privacy': 'Privacy & data',
    'settings.about': 'About this app',

    'privacy.title': 'Your privacy',
    'privacy.intro':
        'This app can send two things to the school’s own server, and nothing '
            'else:',
    'privacy.bullet1':
        '• Anonymous usage counts — which screens are opened and whether a '
            'refresh worked. No names, no accounts.',
    'privacy.bullet2':
        '• Crash reports — the error text, with anything you typed into '
            'Settings removed, so bugs can be fixed.',
    'privacy.never':
        'It never collects your name, student ID, contacts, location, or '
            'advertising identifiers, and it shares nothing with third '
            'parties. There is no third-party analytics.',
    'privacy.offUntil':
        'Both are off unless you turn them on, and you can change this any time '
            'in Settings ▸ Privacy.',
    'privacy.dontShare': 'Don’t share',
    'privacy.share': 'Share anonymously',
    'settings.notifications':
        'Notifications',
    'settings.notificationsSub':
        'Allow Westview HS to send notifications',
    'settings.liveActivity':
        'Live activity',
    'settings.liveOn':
        'Ongoing notification with a countdown to the end of the current period',
    'settings.liveOff':
        'Turn notifications on to use the live activity',
    'settings.privacyData':
        'Privacy & data',
    'settings.analytics':
        'Anonymous usage statistics',
    'settings.analyticsSub':
        'Counts of which screens are opened and whether refreshes succeed. Never identifies you.',
    'settings.crash':
        'Crash reports',
    'settings.crashSub':
        'Error text and stack trace when the app breaks, so it can be fixed. Never identifies you.',
    'settings.collectTitle':
        "What we collect (and don't)",
    'settings.collectBody':
        'Both switches above are off unless you turned them on. When on, the app sends anonymous usage counts and crash reports so it can be fixed — with anything you typed into Settings removed first. It never collects your name, student ID, contacts, location or advertising identifiers. Reports go only to the school server.',
    'settings.savedContent':
        'Saved content',
    'settings.clear':
        'Clear saved content',
    'settings.clearSub':
        'Removes calendars, lunch menus and nutrition data saved for offline use. They download again next time you open them.',
    'settings.cleared':
        'Saved content cleared',
    'settings.classDetails':
        'Class details',
    'settings.showTeacher':
        'Show teacher',
    'settings.showTeacherSub':
        'Show the teacher in the schedule, notification and widget',
    'settings.showRoom':
        'Show room number',
    'settings.showRoomSub':
        'Show the room in the schedule, notification and widget',
    'settings.myClasses':
        'My classes',
    'settings.resetClasses':
        'Reset all class names',
    'settings.resetTitle':
        'Reset class names?',
    'settings.resetBody':
        'This removes every custom name, teacher and room you entered.',
    'settings.reset':
        'Reset',
    'settings.tapToAdd':
        'Tap to add a name, teacher or room',
    'settings.editClass':
        'Class name',
    'settings.leaveEmpty':
        'Leave empty to keep the current name',
    'settings.teacher':
        'Teacher',
    'settings.room':
        'Room number',
    'settings.clearField':
        'Clear',
    'settings.cancel':
        'Cancel',
    'settings.save':
        'Save',
    'settings.notCrisis':
        'This app is not a crisis service and is not monitored. If you or someone else is in danger, call 911. In an emotional crisis, call or text 988.',
    'settings.verified':
        'Schedules, menus and links can be out of date or wrong. Always confirm time-sensitive information with the school office. Counselor contacts were last checked November 2025; the counseling office or the school website is the authoritative source.',
    'settings.langLabel':
        'Language',
    'settings.langSystem':
        'System default',
    'schedule.monFri':
        'Mon/Fri',
    'schedule.tueThu':
        'Tue/Thu',
    'schedule.wed':
        'Wed',
    'schedule.noActivePeriod':
        'No active period',
    'schedule.now':
        'Now',
    'schedule.endsAt': 'ends at',
    'schedule.special':
        'A special schedule is in effect today',
    'schedule.mayNotBeAccurate':
        "Couldn't reach the special-schedule server, so today's schedule may not be accurate.",
    'schedule.dismiss':
        'Dismiss',
    'schedule.checking':
        'Checking for schedule updates',
    'schedule.settings':
        'Settings',
    'schedule.help':
        'Help',
    'schedule.helpTooltip':
        "Get help now. Long-press to leave the app quickly if this screen shouldn't be seen.",
    'common.selected':
        'Selected',
    'common.refresh': 'Refresh page',
    'common.dismiss': 'Dismiss',
    'common.retry': 'Try again',
    'newsletter.weekly': 'Weekly Newsletter',
    'newsletter.counseling': 'Counseling Newsletters',
    'newsletter.den': 'Den Announcements',
    'publications.nexus': 'Westview Nexus',
    'publications.newscast': 'Westview Newscast',
    'web.errorTitle': 'Couldn\'t open this page',
    'web.errorBody': 'The page could not be loaded. Check your connection and try again.',
    'web.loading': 'Loading page…',
    'web.stale': 'Couldn\'t refresh — still showing the last loaded page.',
    'calendar.tabSchool': 'School Calendar',
    'calendar.tabAthletics': 'Athletics',
    'calendar.tabLunch': 'School Lunches',
    'calendar.errorTitle': 'Couldn\'t load calendar events',
    'calendar.errorBody': 'Couldn\'t reach the calendar server. Check your connection and try again.',
    'calendar.loading': 'Loading events…',
    'calendar.emptyTitle': 'No upcoming events',
    'calendar.emptyBody': 'This calendar has nothing scheduled right now. Pull down to refresh.',
    'calendar.savedCopy': 'Saved copy from',
    'calendar.untitled': 'Untitled event',
    'calendar.description': 'Description',
    'calendar.noDescription': 'No description provided.',
    'calendar.allDay': 'All day',
    'calendar.today': 'Today',
    'calendar.yesterday': 'Yesterday',
    'calendar.tomorrow': 'Tomorrow',
    'calendar.weekdays': 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
    'calendar.am': 'AM',
    'calendar.pm': 'PM',
    'schedule.refresh': 'Refreshing schedule…',
    'settings.langPickTitle': 'App language',
    'web.retry': 'Try again',
    'common.loading': 'Loading…',
    'common.errorTitle': 'Can\'t load this right now',
    'help.iconTooltip': 'Get help now',
    'help.iconTooltipQuickExit': '%s (long-press leaves the app immediately)',
    'lunch.errorTitle': 'Couldn\'t load the lunch menu',
    'lunch.errorBody': 'Couldn\'t reach the menu server. Check your connection and try again.',
    'lunch.loading': 'Loading the menu…',
    'lunch.emptyTitle': 'No lunch menu published',
    'lunch.emptyBody': 'This month\'s menu hasn\'t been published yet. Pull down to refresh.',
    'lunch.savedCopy': 'Saved menu from',
    'lunch.noSchool': 'No school',
    'lunch.entrees': 'Lunch Entrees',
    'lunch.vegetables': 'Vegetables',
    'lunch.fruit': 'Fruit & Juice',
    'lunch.milk': 'Milk Choice',
    'lunch.noFactsFor': 'No nutrition facts available for %s',
    'lunch.servingSize': 'Serving size',
    'lunch.oneServing': '1 serving',
    'lunch.noNutrition': 'No detailed nutrition data available.',
    'lunch.nutritionFacts': 'Nutrition Facts',
    'lunch.calories': 'Calories',
    'lunch.totalFat': 'Total fat',
    'lunch.saturatedFat': 'Saturated fat',
    'lunch.transFat': 'Trans fat',
    'lunch.cholesterol': 'Cholesterol',
    'lunch.sodium': 'Sodium',
    'lunch.carbs': 'Carbohydrates',
    'lunch.fiber': 'Dietary fiber',
    'lunch.sugars': 'Sugars',
    'lunch.protein': 'Protein',
    'help.counselor.callA11y': 'Call %s',
    'help.counselor.emailA11y': 'Email %s',
    'help.counselor.emailSubject': 'Student question for my counselor',
    'help.counselor.careerTitle': 'College & career guidance',
    'help.counselor.careerRole': 'College & Career Guidance Technician',
    'settings.roomShort': 'Rm',
  },

  // -------------------------------------------------------------------- Español
  'es': {
    'app.title': 'Westview HS',
    'nav.schedule': 'Horario',
    'nav.newsletters': 'Boletines',
    'nav.publications': 'Publicaciones',
    'nav.calendars': 'Calendario',
    'nav.getHelp': 'Ayuda',
    'common.call': 'Llamar',
    'common.text': 'Texto',
    'common.website': 'Sitio web',
    'common.close': 'Cerrar',
    'common.cancel': 'Cancelar',
    'common.openInBrowser': 'Abrir en el navegador',
    'common.copyNumber':
        'Copiar este número',
    'sms.confirmTitle':
        '¿Enviar este mensaje?',
    'sms.openApp':
        'Abrir Mensajes',
    'sms.editNote':
        'Se abrirá tu aplicación de mensajes con este texto listo para enviar. Puedes editarlo o añadir más antes de enviarlo.',

    'disclaimer.short':
        'No es una aplicación de Poway Unified. No está patrocinada ni avalada '
            'por el Distrito Escolar Unificado de Poway ni por Westview High '
            'School.',
    'disclaimer.title': 'Esta aplicación no forma parte de Poway Unified',
    'disclaimer.plain':
        'En palabras simples: Westview HS (WVAA) es una aplicación hecha por '
            'estudiantes. El Distrito Escolar Unificado de Poway y Westview '
            'High School no la crearon, no la administran y no la han revisado. '
            'Lo que aparece aquí puede estar desactualizado o ser incorrecto; '
            'confirma siempre con la oficina de la escuela, tu consejero o el '
            'sitio web de la escuela.',
    'disclaimer.crisis':
        'Esta aplicación no es un servicio de crisis y nadie la monitorea. Si '
            'tú o alguien más está en peligro, llama al 911. En una crisis '
            'emocional, llama o envía un texto al 988.',
    'disclaimer.translationNote':
        'Las traducciones del aviso legal se ofrecen para ayudarte a '
            'entenderlo. La versión oficial en inglés y español que exige el '
            'distrito es la que rige.',

    'help.title': 'Ayuda',
    'help.emergency.title': '¿Peligro inmediato?',
    'help.emergency.body':
        'Llama al 911 ahora si tú o alguien más está a punto de salir herido, '
            'o si necesitas ayuda en este momento.',
    'help.emergency.call': 'Llamar al 911',
    'help.emergency.note':
        'Si no sabes si es una emergencia, llama o envía un texto al 988. '
            'Alguien contestará y te ayudará a decidir qué hacer.',

    'help.counselor.title': 'Habla con un consejero de Westview',
    'help.counselor.body':
        'Los consejeros están en el Wolverine Center durante el día escolar. '
            'Puedes pasar sin cita, pedirle a un maestro que te ayude a llegar, '
            'o escribirle a tu consejero directamente. No tienes que explicar '
            'todo para pedir una cita.',
    'help.counselor.callOffice': 'Llamar a la oficina',
    'help.counselor.website': 'Sitio de consejería',
    'help.counselor.find': 'Encuentra a tu consejero',
    'help.counselor.byLast': 'Según la primera letra de tu apellido.',
    'help.counselor.career': 'Preguntas sobre universidad y carrera',
    'help.counselor.verified':
        'El personal y las letras asignadas pueden cambiar durante el año. '
            'Consulta el sitio web de la escuela o la oficina de consejería si '
            'la letra de tu apellido no aparece. (Lista revisada en noviembre '
            'de 2025.)',

    'help.crisis.title': 'Líneas de crisis — gratis, confidenciales, 24/7',
    'help.crisis.call': 'Llamar',
    'help.crisis.text': 'Texto',
    'help.crisis.deaf':
        '¿Tienes pérdida auditiva o no puedes hablar por teléfono? Todas las '
            'opciones de abajo también funcionan por texto o en línea. El 988 y '
            'Crisis Text Line están pensados para texto, y a la línea del '
            'Condado de San Diego también se llega con un operador de relevo: '
            'marca 711.',

    'help.report.title': 'Reportar un problema de seguridad',
    'help.report.body':
        '¿Te preocupa un compañero, una amenaza, un arma o algo que viste en '
            'línea? Cuéntale a un adulto de confianza: un maestro, tu consejero, '
            'un entrenador o un familiar. También puedes reportarlo de forma '
            'anónima:',
    'help.report.note':
        'No tienes que estar seguro. Los reportes pueden equivocarse y está '
            'bien: quienes los revisan están capacitados para eso.',

    'help.about.title': 'Sobre esta aplicación',

    'hotline.988.name': 'Línea 988 de Prevención del Suicidio y Crisis',
    'hotline.988.desc':
        'Apoyo gratuito y confidencial para cualquier persona en angustia '
            'emocional o crisis suicida. Llama o envía un texto a cualquier '
            'hora, de día o de noche.',
    'hotline.988.call': 'Llamar al 988',
    'hotline.988.sms': 'Texto al 988',
    'hotline.sdaocl.name': 'Línea de Acceso y Crisis de San Diego',
    'hotline.sdaocl.desc':
        'La línea 24/7 del Condado de San Diego para crisis de salud mental y '
            'de consumo de sustancias, para ti o para alguien que te preocupa. '
            'Intérpretes gratuitos en más de 200 idiomas. También pueden enviar '
            'un equipo móvil de respuesta a crisis.',
    'hotline.sdaocl.call': 'Llamar al 1-888-724-7240',
    'hotline.crisistext.name': 'Crisis Text Line (línea de texto)',
    'hotline.crisistext.desc':
        '¿Prefieres escribir a hablar? Envía un texto a un voluntario '
            'capacitado sobre lo que te preocupa. Gratis, 24/7 y confidencial.',
    'hotline.crisistext.sms': 'Envía HOME al 741741',
    'hotline.trevor.name': 'The Trevor Project',
    'hotline.trevor.desc':
        'Apoyo en crisis y prevención del suicidio para jóvenes LGBTQ+, 24/7. '
            'Mereces que te tomen en serio.',
    'hotline.trevor.call': 'Llamar al 1-866-488-7386',
    'hotline.trevor.sms': 'Envía START al 678678',
    'hotline.sandyhook.name': 'Reportes anónimos Say Something',
    'hotline.sandyhook.desc':
        'Forma anónima de reportar amenazas, armas o alguien que pueda estar en '
            'peligro; contestan consejeros de crisis. Sirve para “me preocupa un '
            'compañero”, no solo para emergencias.',
    'hotline.sandyhook.call': 'Llamar al 1-844-5-SAYNOW',
    'hotline.pusdtip.name': 'Línea de reportes “See Something, Say Something” '
        'de PUSD',
    'hotline.pusdtip.desc':
        'Línea anónima de Poway Unified, disponible 24 horas y monitoreada por '
            'la policía, para amenazas y problemas de seguridad escolar. El '
            'número está en el reverso de tu credencial de estudiante.',
    'hotline.pusdtip.call': 'Llamar al 1-844-PUSD-TIP',

    'settings.title': 'Ajustes',
    'settings.safety': 'Seguridad',
    'settings.getHelp': 'Obtener ayuda ahora',
    'settings.getHelpSub':
        'Consejeros de Westview, líneas de crisis y cómo reportar un problema '
            'de seguridad. Funciona sin conexión.',
    'settings.quickExit': 'Salida rápida',
    'settings.quickExitSub':
        'Mantén presionado el botón de Ayuda para salir de la aplicación de '
            'inmediato. Nada de lo que mirabas queda en pantalla.',
    'settings.hideRecents': 'Ocultar la vista previa en el selector de apps',
    'settings.hideRecentsSub':
        'Evita que la última pantalla aparezca en la lista de aplicaciones '
            'recientes (Android).',
    'settings.language': 'Idioma',
    'settings.languageSub': 'Se aplica a Ayuda, Ajustes y la navegación.',
    'settings.privacy': 'Privacidad y datos',
    'settings.about': 'Sobre esta aplicación',

    'privacy.title': 'Tu privacidad',
    'privacy.intro':
        'Esta aplicación puede enviar dos cosas al servidor de la escuela, y '
            'nada más:',
    'privacy.bullet1':
        '• Conteos de uso anónimos: qué pantallas se abren y si una '
            'actualización funcionó. Sin nombres ni cuentas.',
    'privacy.bullet2':
        '• Reportes de fallos: el texto del error, con lo que escribiste en '
            'Ajustes eliminado, para poder corregirlo.',
    'privacy.never':
        'Nunca recopila tu nombre, número de estudiante, contactos, ubicación '
            'ni identificadores publicitarios, y no comparte nada con terceros. '
            'No hay analítica de terceros.',
    'privacy.offUntil':
        'Ambas funciones están desactivadas a menos que las actives, y puedes '
            'cambiarlo cuando quieras en Ajustes ▸ Privacidad.',
    'privacy.dontShare': 'No compartir',
    'privacy.share': 'Compartir de forma anónima',
    'settings.notifications':
        'Notificaciones',
    'settings.notificationsSub':
        'Permitir que Westview HS envíe notificaciones',
    'settings.liveActivity':
        'Actividad en curso',
    'settings.liveOn':
        'Notificación permanente con cuenta regresiva hasta el final del período actual',
    'settings.liveOff':
        'Activa las notificaciones para usar la actividad en curso',
    'settings.privacyData':
        'Privacidad y datos',
    'settings.analytics':
        'Estadísticas de uso anónimas',
    'settings.analyticsSub':
        'Cuántas veces se abren las pantallas y si las actualizaciones funcionan. Nunca te identifica.',
    'settings.crash':
        'Reportes de fallos',
    'settings.crashSub':
        'El texto del error y el rastro de pila cuando falla la aplicación, para poder corregirlo. Nunca te identifica.',
    'settings.collectTitle':
        'Qué recopilamos (y qué no)',
    'settings.collectBody':
        'Las dos opciones de arriba están desactivadas a menos que las actives. Cuando están activas, la aplicación envía conteos de uso anónimos y reportes de fallos para poder mejorarla, después de eliminar lo que hayas escrito en Ajustes. Nunca recopila tu nombre, número de estudiante, contactos, ubicación ni identificadores publicitarios. Los reportes van solo al servidor de la escuela.',
    'settings.savedContent':
        'Contenido guardado',
    'settings.clear':
        'Borrar contenido guardado',
    'settings.clearSub':
        'Elimina calendarios, menús de almuerzo y datos de nutrición guardados para uso sin conexión. Se descargan de nuevo cuando los abras.',
    'settings.cleared':
        'Contenido guardado borrado',
    'settings.classDetails':
        'Datos de las clases',
    'settings.showTeacher':
        'Mostrar maestro',
    'settings.showTeacherSub':
        'Mostrar el maestro en el horario, la notificación y el widget',
    'settings.showRoom':
        'Mostrar número de salón',
    'settings.showRoomSub':
        'Mostrar el salón en el horario, la notificación y el widget',
    'settings.myClasses':
        'Mis clases',
    'settings.resetClasses':
        'Restablecer todos los nombres',
    'settings.resetTitle':
        '¿Restablecer los nombres?',
    'settings.resetBody':
        'Esto elimina todos los nombres, maestros y salones que ingresaste.',
    'settings.reset':
        'Restablecer',
    'settings.tapToAdd':
        'Toca para añadir nombre, maestro o salón',
    'settings.editClass':
        'Nombre de la clase',
    'settings.leaveEmpty':
        'Déjalo vacío para mantener el nombre actual',
    'settings.teacher':
        'Maestro',
    'settings.room':
        'Número de salón',
    'settings.clearField':
        'Borrar',
    'settings.cancel':
        'Cancelar',
    'settings.save':
        'Guardar',
    'settings.notCrisis':
        'Esta aplicación no es un servicio de crisis y nadie la monitorea. Si tú o alguien más está en peligro, llama al 911. En una crisis emocional, llama o envía un texto al 988.',
    'settings.verified':
        'Los horarios, menús y enlaces pueden estar desactualizados o ser incorrectos. Confirma siempre la información urgente con la oficina de la escuela. Los contactos de consejería se revisaron por última vez en noviembre de 2025; la oficina de consejería y el sitio web de la escuela son la fuente oficial.',
    'settings.langLabel':
        'Idioma',
    'settings.langSystem':
        'Predeterminado del sistema',
    'schedule.monFri':
        'Lun/Vie',
    'schedule.tueThu':
        'Mar/Jue',
    'schedule.wed':
        'Mié',
    'schedule.noActivePeriod':
        'Ningún período activo',
    'schedule.now':
        'Ahora',
    'schedule.endsAt': 'termina a las',
    'schedule.special':
        'Hoy hay un horario especial',
    'schedule.mayNotBeAccurate':
        'No se pudo conectar con el servidor, así que el horario de hoy puede no ser exacto.',
    'schedule.dismiss':
        'Cerrar',
    'schedule.checking':
        'Buscando cambios de horario',
    'schedule.settings':
        'Ajustes',
    'schedule.help':
        'Ayuda',
    'schedule.helpTooltip':
        'Obtener ayuda ahora. Mantén presionado para salir de la aplicación rápidamente si no quieres que se vea esta pantalla.',
    'common.selected':
        'Seleccionado',
    'common.refresh': 'Actualizar',
    'common.dismiss': 'Descartar',
    'common.retry': 'Reintentar',
    'newsletter.weekly': 'Boletín semanal',
    'newsletter.counseling': 'Boletines de consejería',
    'newsletter.den': 'Anuncios del Den',
    'publications.nexus': 'Westview Nexus',
    'publications.newscast': 'Noticiero de Westview',
    'web.errorTitle': 'No se pudo abrir esta página',
    'web.errorBody': 'No se pudo cargar la página. Revisa tu conexión e inténtalo de nuevo.',
    'web.loading': 'Cargando página…',
    'web.stale': 'No se pudo actualizar; se sigue mostrando la última página cargada.',
    'calendar.tabSchool': 'Calendario escolar',
    'calendar.tabAthletics': 'Deportes',
    'calendar.tabLunch': 'Almuerzos escolares',
    'calendar.errorTitle': 'No se pudieron cargar los eventos',
    'calendar.errorBody': 'No se pudo conectar con el servidor del calendario. Revisa tu conexión e inténtalo de nuevo.',
    'calendar.loading': 'Cargando eventos…',
    'calendar.emptyTitle': 'No hay eventos próximos',
    'calendar.emptyBody': 'Este calendario no tiene nada programado ahora. Desliza hacia abajo para actualizar.',
    'calendar.savedCopy': 'Copia guardada del',
    'calendar.untitled': 'Evento sin título',
    'calendar.description': 'Descripción',
    'calendar.noDescription': 'No se proporcionó descripción.',
    'calendar.allDay': 'Todo el día',
    'calendar.today': 'Hoy',
    'calendar.yesterday': 'Ayer',
    'calendar.tomorrow': 'Mañana',
    'calendar.weekdays': 'lunes,martes,miércoles,jueves,viernes,sábado,domingo',
    'calendar.am': 'a. m.',
    'calendar.pm': 'p. m.',
    'schedule.refresh': 'Actualizando horario…',
    'settings.langPickTitle': 'Idioma de la aplicación',
    'web.retry': 'Reintentar',
    'common.loading': 'Cargando…',
    'common.errorTitle': 'No se puede cargar en este momento',
    'help.iconTooltip': 'Obtener ayuda ahora',
    'help.iconTooltipQuickExit': '%s (mantén presionado para salir de la aplicación de inmediato)',
    'lunch.errorTitle': 'No se pudo cargar el menú',
    'lunch.errorBody': 'No se pudo conectar con el servidor del menú. Revisa tu conexión e inténtalo de nuevo.',
    'lunch.loading': 'Cargando el menú…',
    'lunch.emptyTitle': 'No hay menú publicado',
    'lunch.emptyBody': 'El menú de este mes aún no se ha publicado. Desliza hacia abajo para actualizar.',
    'lunch.savedCopy': 'Menú guardado del',
    'lunch.noSchool': 'No hay clases',
    'lunch.entrees': 'Platos principales',
    'lunch.vegetables': 'Verduras',
    'lunch.fruit': 'Frutas y jugos',
    'lunch.milk': 'Elección de leche',
    'lunch.noFactsFor': 'No hay datos nutricionales para %s',
    'lunch.servingSize': 'Porción',
    'lunch.oneServing': '1 porción',
    'lunch.noNutrition': 'No hay datos nutricionales detallados.',
    'lunch.nutritionFacts': 'Información nutricional',
    'lunch.calories': 'Calorías',
    'lunch.totalFat': 'Grasa total',
    'lunch.saturatedFat': 'Grasa saturada',
    'lunch.transFat': 'Grasa trans',
    'lunch.cholesterol': 'Colesterol',
    'lunch.sodium': 'Sodio',
    'lunch.carbs': 'Carbohidratos',
    'lunch.fiber': 'Fibra dietética',
    'lunch.sugars': 'Azúcares',
    'lunch.protein': 'Proteína',
    'help.counselor.callA11y': 'Llamar a %s',
    'help.counselor.emailA11y': 'Enviar correo a %s',
    'help.counselor.emailSubject': 'Pregunta de estudiante para mi consejero',
    'help.counselor.careerTitle': 'Orientación universitaria y profesional',
    'help.counselor.careerRole': 'Técnica de orientación universitaria y profesional',
    'settings.roomShort': 'Aula',
  },

  // ------------------------------------------------------------------ 简体中文
  'zh': {
    'app.title': 'Westview HS',
    'nav.schedule': '课表',
    'nav.newsletters': '简报',
    'nav.publications': '刊物',
    'nav.calendars': '日历',
    'nav.getHelp': '求助',
    'common.call': '拨打',
    'common.text': '发短信',
    'common.website': '网站',
    'common.close': '关闭',
    'common.cancel': '取消',
    'common.openInBrowser': '在浏览器中打开',
    'common.copyNumber':
        '复制此号码',
    'sms.confirmTitle':
        '要发送这条短信吗？',
    'sms.openApp':
        '打开信息',
    'sms.editNote':
        '你的短信应用会打开，并已填好这条内容。发送前你可以修改或补充。',

    'disclaimer.short':
        '本应用不属于 Poway 联合学区，未获 Poway 联合学区或 Westview 高中赞助或认可。',
    'disclaimer.title': '本应用不属于 Poway 联合学区',
    'disclaimer.plain':
        '简单来说：Westview HS（WVAA）是由学生开发的辅助应用。Poway 联合学区和 '
            'Westview 高中没有制作、没有运营，也没有审核过它。这里的任何内容都可能过时或'
            '有误——请始终向学校办公室、你的辅导员或学校网站确认。',
    'disclaimer.crisis':
        '本应用不是危机服务，也没有人实时查看。如果你或他人处于危险中，请拨打 911。'
            '遇到情绪危机时，请拨打或发送短信至 988。',
    'disclaimer.translationNote':
        '免责声明的译文仅供帮助你理解。以学区要求的官方英文和西班牙文版本为准。',

    'help.title': '求助',
    'help.emergency.title': '有立即危险吗？',
    'help.emergency.body': '如果你或他人即将受到伤害，或你现在就需要帮助，请立即拨打 911。',
    'help.emergency.call': '拨打 911',
    'help.emergency.note':
        '如果你不确定是否属于紧急情况，请拨打或发送短信至 988。会有人接听并帮你决定下一步。',

    'help.counselor.title': '与 Westview 的辅导员谈谈',
    'help.counselor.body':
        '上课日辅导员在 Wolverine Center。你可以直接走过去，请老师帮你过去，或直接给你'
            '的辅导员发邮件——预约时不需要解释所有事情。',
    'help.counselor.callOffice': '致电办公室',
    'help.counselor.website': '辅导网站',
    'help.counselor.find': '找到你的辅导员',
    'help.counselor.byLast': '按姓氏首字母分配。',
    'help.counselor.career': '升学与职业问题',
    'help.counselor.verified':
        '人员和负责的字母范围可能在学年中变动。如果未列出你姓氏的首字母，请查看学校网站'
            '或咨询办公室。（名单核对时间：2025 年 11 月。）',

    'help.crisis.title': '危机热线——免费、保密、24 小时',
    'help.crisis.call': '拨打',
    'help.crisis.text': '短信',
    'help.crisis.deaf':
        '听力不便或无法用电话交谈？下面的每一种方式也都可以通过短信或网络使用。988 和 '
            'Crisis Text Line 以短信为主，圣地亚哥县的电话线也可通过中继接线员拨打：拨打 711。',

    'help.report.title': '报告安全问题',
    'help.report.body':
        '担心同学、威胁、武器，或在网上看到的内容？请告诉一位你信任的成年人——老师、'
            '辅导员、教练或家长。你也可以匿名报告：',
    'help.report.note':
        '你不需要百分之百确定。报告可能有误，这没关系——审核报告的人受过专业训练。',

    'help.about.title': '关于本应用',

    'hotline.988.name': '988 自杀与危机生命线',
    'hotline.988.desc':
        '为处于情绪困扰或自杀危机中的任何人提供免费、保密的支持。全天候可拨打或发短信。',
    'hotline.988.call': '拨打 988',
    'hotline.988.sms': '短信 988',
    'hotline.sdaocl.name': '圣地亚哥心理援助与危机热线',
    'hotline.sdaocl.desc':
        '圣地亚哥县 24 小时心理健康与药物使用危机热线，可为你或你担心的人拨打。提供 200 '
            '多种语言的免费翻译。也可派出移动危机响应团队。',
    'hotline.sdaocl.call': '拨打 1-888-724-7240',
    'hotline.crisistext.name': 'Crisis Text Line（短信热线）',
    'hotline.crisistext.desc':
        '比起说话更愿意打字？把困扰你的事发短信给受过训练的志愿者。免费、24 小时、保密。',
    'hotline.crisistext.sms': '发送 HOME 至 741741',
    'hotline.trevor.name': 'The Trevor Project',
    'hotline.trevor.desc': '为 LGBTQ+ 青少年提供 24 小时危机与自杀预防支持。你值得被认真对待。',
    'hotline.trevor.call': '拨打 1-866-488-7386',
    'hotline.trevor.sms': '发送 START 至 678678',
    'hotline.sandyhook.name': 'Say Something 匿名报告',
    'hotline.sandyhook.desc':
        '匿名报告威胁、武器或可能处于危险中的人——由危机辅导员接听。适合“我担心某个同学”，'
            '不只用于紧急情况。',
    'hotline.sandyhook.call': '拨打 1-844-5-SAYNOW',
    'hotline.pusdtip.name': 'PUSD“See Something, Say Something”举报热线',
    'hotline.pusdtip.desc':
        'Poway 联合学区的 24 小时匿名举报热线，由执法部门监控，用于报告校园威胁和安全问题。'
            '号码印在你的学生证背面。',
    'hotline.pusdtip.call': '拨打 1-844-PUSD-TIP',

    'settings.title': '设置',
    'settings.safety': '安全',
    'settings.getHelp': '立即求助',
    'settings.getHelpSub': 'Westview 辅导员、危机热线，以及如何报告安全问题。离线也可使用。',
    'settings.quickExit': '快速离开',
    'settings.quickExitSub': '长按“求助”按钮立即离开应用。你刚才看的内容不会留在屏幕上。',
    'settings.hideRecents': '在多任务中隐藏预览',
    'settings.hideRecentsSub': '让最近任务列表中不显示应用的最后一屏（Android）。',
    'settings.language': '语言',
    'settings.languageSub': '适用于求助、设置和导航。',
    'settings.privacy': '隐私与数据',
    'settings.about': '关于本应用',

    'privacy.title': '你的隐私',
    'privacy.intro': '本应用最多向学校自己的服务器发送两项内容，除此之外没有别的：',
    'privacy.bullet1': '• 匿名使用次数——打开了哪些页面、刷新是否成功。不含姓名或账号。',
    'privacy.bullet2': '• 崩溃报告——错误文本，并已删除你在设置中输入的内容，以便修复问题。',
    'privacy.never':
        '它绝不收集你的姓名、学号、通讯录、位置或广告标识符，也不与第三方共享。没有第三方分析工具。',
    'privacy.offUntil': '除非你主动开启，两项功能都处于关闭状态；你可随时在“设置 ▸ 隐私”中更改。',
    'privacy.dontShare': '不分享',
    'privacy.share': '匿名分享',
    'settings.notifications':
        '通知',
    'settings.notificationsSub':
        '允许 Westview HS 发送通知',
    'settings.liveActivity':
        '实时活动',
    'settings.liveOn':
        '显示本节剩余时间的常驻通知',
    'settings.liveOff':
        '开启通知后才能使用实时活动',
    'settings.privacyData':
        '隐私与数据',
    'settings.analytics':
        '匿名使用统计',
    'settings.analyticsSub':
        '记录打开了哪些页面、刷新是否成功。不会识别你的身份。',
    'settings.crash':
        '崩溃报告',
    'settings.crashSub':
        '应用出错时的错误文本和堆栈，用于修复问题。不会识别你的身份。',
    'settings.collectTitle':
        '我们收集什么（以及不收集什么）',
    'settings.collectBody':
        '除非你主动开启，上面两个开关都处于关闭状态。开启后，应用会发送匿名使用统计和崩溃报告以便改进，发送前会先删除你在设置中输入的内容。它绝不收集你的姓名、学号、通讯录、位置或广告标识符。报告只发送到学校服务器。',
    'settings.savedContent':
        '已保存的内容',
    'settings.clear':
        '清除已保存内容',
    'settings.clearSub':
        '删除为离线使用而保存的日历、午餐菜单和营养数据。下次打开时会重新下载。',
    'settings.cleared':
        '已清除保存的内容',
    'settings.classDetails':
        '课程信息',
    'settings.showTeacher':
        '显示老师',
    'settings.showTeacherSub':
        '在课表、通知和小组件中显示老师',
    'settings.showRoom':
        '显示教室号',
    'settings.showRoomSub':
        '在课表、通知和小组件中显示教室',
    'settings.myClasses':
        '我的课程',
    'settings.resetClasses':
        '重置所有课程名称',
    'settings.resetTitle':
        '重置课程名称？',
    'settings.resetBody':
        '这会删除你输入的所有名称、老师和教室。',
    'settings.reset':
        '重置',
    'settings.tapToAdd':
        '点按添加名称、老师或教室',
    'settings.editClass':
        '课程名称',
    'settings.leaveEmpty':
        '留空则保留当前名称',
    'settings.teacher':
        '老师',
    'settings.room':
        '教室号',
    'settings.clearField':
        '清除',
    'settings.cancel':
        '取消',
    'settings.save':
        '保存',
    'settings.notCrisis':
        '本应用不是危机服务，也没有人实时查看。如果你或他人处于危险中，请拨打 911。遇到情绪危机时，请拨打或发送短信至 988。',
    'settings.verified':
        '课表、菜单和链接可能过时或有误。时间敏感的信息请务必向学校办公室确认。辅导员联系方式最后核对于 2025 年 11 月；以辅导办公室和学校网站为准。',
    'settings.langLabel':
        '语言',
    'settings.langSystem':
        '跟随系统',
    'schedule.monFri':
        '周一/周五',
    'schedule.tueThu':
        '周二/周四',
    'schedule.wed':
        '周三',
    'schedule.noActivePeriod':
        '当前没有课程',
    'schedule.now':
        '现在',
    'schedule.endsAt': '结束于',
    'schedule.special':
        '今天有特殊课表',
    'schedule.mayNotBeAccurate':
        '无法连接课表服务器，今天的课表可能不准确。',
    'schedule.dismiss':
        '关闭',
    'schedule.checking':
        '正在检查课表更新',
    'schedule.settings':
        '设置',
    'schedule.help':
        '求助',
    'schedule.helpTooltip':
        '立即求助。长按可快速离开应用（如果不想让别人看到此页面）。',
    'common.selected':
        '已选择',
    'common.refresh': '刷新',
    'common.dismiss': '关闭',
    'common.retry': '重试',
    'newsletter.weekly': '每周通讯',
    'newsletter.counseling': '辅导通讯',
    'newsletter.den': 'Den 公告',
    'publications.nexus': 'Westview Nexus',
    'publications.newscast': 'Westview 新闻播报',
    'web.errorTitle': '无法打开此页面',
    'web.errorBody': '页面无法加载。请检查网络连接后重试。',
    'web.loading': '正在加载页面…',
    'web.stale': '无法刷新，仍在显示上次加载的页面。',
    'calendar.tabSchool': '学校日历',
    'calendar.tabAthletics': '体育赛事',
    'calendar.tabLunch': '学校午餐',
    'calendar.errorTitle': '无法加载日历活动',
    'calendar.errorBody': '无法连接日历服务器。请检查网络连接后重试。',
    'calendar.loading': '正在加载活动…',
    'calendar.emptyTitle': '暂无即将举行的活动',
    'calendar.emptyBody': '此日历目前没有安排。下拉可刷新。',
    'calendar.savedCopy': '已保存副本：',
    'calendar.untitled': '未命名活动',
    'calendar.description': '说明',
    'calendar.noDescription': '没有提供说明。',
    'calendar.allDay': '全天',
    'calendar.today': '今天',
    'calendar.yesterday': '昨天',
    'calendar.tomorrow': '明天',
    'calendar.weekdays': '星期一,星期二,星期三,星期四,星期五,星期六,星期日',
    'calendar.am': '上午',
    'calendar.pm': '下午',
    'schedule.refresh': '正在刷新课程表…',
    'settings.langPickTitle': '应用语言',
    'web.retry': '重试',
    'common.loading': '正在加载…',
    'common.errorTitle': '目前无法加载',
    'help.iconTooltip': '立即求助',
    'help.iconTooltipQuickExit': '%s（长按即可立即退出应用）',
    'lunch.errorTitle': '无法加载午餐菜单',
    'lunch.errorBody': '无法连接菜单服务器。请检查网络连接后重试。',
    'lunch.loading': '正在加载菜单…',
    'lunch.emptyTitle': '尚未发布午餐菜单',
    'lunch.emptyBody': '本月的菜单尚未发布。下拉可刷新。',
    'lunch.savedCopy': '已保存菜单：',
    'lunch.noSchool': '停课',
    'lunch.entrees': '午餐主菜',
    'lunch.vegetables': '蔬菜',
    'lunch.fruit': '水果与果汁',
    'lunch.milk': '奶类选择',
    'lunch.noFactsFor': '没有 %s 的营养信息',
    'lunch.servingSize': '份量',
    'lunch.oneServing': '1 份',
    'lunch.noNutrition': '没有详细的营养数据。',
    'lunch.nutritionFacts': '营养信息',
    'lunch.calories': '热量',
    'lunch.totalFat': '总脂肪',
    'lunch.saturatedFat': '饱和脂肪',
    'lunch.transFat': '反式脂肪',
    'lunch.cholesterol': '胆固醇',
    'lunch.sodium': '钠',
    'lunch.carbs': '碳水化合物',
    'lunch.fiber': '膳食纤维',
    'lunch.sugars': '糖',
    'lunch.protein': '蛋白质',
    'help.counselor.callA11y': '致电 %s',
    'help.counselor.emailA11y': '给 %s 发邮件',
    'help.counselor.emailSubject': '学生咨询（致辅导员）',
    'help.counselor.careerTitle': '升学与职业指导',
    'help.counselor.careerRole': '升学与职业指导技术员',
    'settings.roomShort': '教室',
  },

  // ------------------------------------------------------------------ Filipino
  'tl': {
    'app.title': 'Westview HS',
    'nav.schedule': 'Iskedyul',
    'nav.newsletters': 'Balitaan',
    'nav.publications': 'Pahayagan',
    'nav.calendars': 'Kalendaryo',
    'nav.getHelp': 'Tulong',
    'common.call': 'Tumawag',
    'common.text': 'Mag-text',
    'common.website': 'Website',
    'common.close': 'Isara',
    'common.cancel': 'Kanselahin',
    'common.openInBrowser': 'Buksan sa browser',
    'common.copyNumber':
        'Kopyahin ang numerong ito',
    'sms.confirmTitle':
        'Ipadala ang text na ito?',
    'sms.openApp':
        'Buksan ang Messages',
    'sms.editNote':
        'Bubukas ang messaging app mo na may nakasulat nang mensahe. Maaari mong i-edit o dagdagan bago ipadala.',

    'disclaimer.short':
        'Hindi ito app ng Poway Unified. Hindi ito itinataguyod o sinusuportahan ng '
            'Poway Unified School District o ng Westview High School.',
    'disclaimer.title': 'Hindi bahagi ng Poway Unified ang app na ito',
    'disclaimer.plain':
        'Sa simpleng salita: ang Westview HS (WVAA) ay app na ginawa ng mga estudyante. '
            'Hindi ito ginawa, pinapatakbo, o sinuri ng Poway Unified School District at '
            'ng Westview High School. Maaaring luma o mali ang anumang makita rito — '
            'palaging i-verify sa opisina ng paaralan, sa iyong counselor, o sa website '
            'ng paaralan.',
    'disclaimer.crisis':
        'Hindi serbisyo para sa krisis ang app na ito at walang nagbabantay dito. Kung '
            'ikaw o ang iba ay nasa panganib, tumawag sa 911. Sa emosyonal na krisis, '
            'tumawag o mag-text sa 988.',
    'disclaimer.translationNote':
        'Ang salin ng disclaimer ay para lamang maintindihan ito. Ang opisyal na '
            'Ingles at Espanyol na bersyon na hinihiling ng distrito ang sinusunod.',

    'help.title': 'Tulong',
    'help.emergency.title': 'May agarang panganib ba?',
    'help.emergency.body':
        'Tumawag agad sa 911 kung ikaw o ang iba ay malapit nang masaktan, o kailangan mo '
            'ng tulong ngayon mismo.',
    'help.emergency.call': 'Tumawag sa 911',
    'help.emergency.note':
        'Kung hindi ka sigurado kung emergency ito, tumawag o mag-text sa 988. May sasagot '
            'at tutulungan kang magpasya sa susunod na hakbang.',

    'help.counselor.title': 'Kausapin ang counselor sa Westview',
    'help.counselor.body':
        'Nasa Wolverine Center ang mga counselor sa oras ng klase. Maaari kang dumaan, '
            'humiling ng tulong sa teacher para makapunta roon, o mag-email nang direkta sa '
            'iyong counselor — hindi mo kailangang ipaliwanag lahat para makakuha ng '
            'appointment.',
    'help.counselor.callOffice': 'Tumawag sa opisina',
    'help.counselor.website': 'Website ng counseling',
    'help.counselor.find': 'Hanapin ang iyong counselor',
    'help.counselor.byLast': 'Batay sa unang letra ng iyong apelyido.',
    'help.counselor.career': 'Mga tanong sa kolehiyo at karera',
    'help.counselor.verified':
        'Maaaring magbago ang staff at assignment sa loob ng taon. Tingnan ang website ng '
            'paaralan o ang counseling office kung wala ang letra ng iyong apelyido. '
            '(Sinuri noong Nobyembre 2025.)',

    'help.crisis.title': 'Mga crisis line — libre, kompidensyal, 24/7',
    'help.crisis.call': 'Tumawag',
    'help.crisis.text': 'Mag-text',
    'help.crisis.deaf':
        'May problema sa pandinig o hindi makapagsalita sa telepono? Lahat ng '
            'opsyon sa ibaba ay gumagana rin sa text o online. Ang 988 at Crisis '
            'Text Line ay text-first, at maaari ring abutin ang linya ng San '
            'Diego County sa pamamagitan ng relay operator: i-dial ang 711.',

    'help.report.title': 'Iulat ang isyu sa kaligtasan',
    'help.report.body':
        'May nag-aalala sa iyong kaklase, isang banta, armas, o nakita mo sa online? Sabihin '
            'sa mapagkakatiwalaang matanda — teacher, counselor, coach, o magulang. Maaari '
            'ding iulat ito nang anonymous:',
    'help.report.note':
        'Hindi mo kailangang maging sigurado. Maaaring magkamali ang ulat at okay lang '
            'iyon — sinanay ang mga nagche-check nito.',

    'help.about.title': 'Tungkol sa app na ito',

    'hotline.988.name': '988 Suicide & Crisis Lifeline',
    'hotline.988.desc':
        'Libre at kompidensyal na suporta para sa sinumang may emosyonal na paghihirap o '
            'krisis sa pagpapatiwakal. Tumawag o mag-text anumang oras.',
    'hotline.988.call': 'Tumawag sa 988',
    'hotline.988.sms': 'I-text ang 988',
    'hotline.sdaocl.name': 'San Diego Access & Crisis Line',
    'hotline.sdaocl.desc':
        '24/7 na linya ng San Diego County para sa mental health at substance use crisis, '
            'para sa iyo o sa taong nag-aalala ka. Libreng interpreter sa 200+ wika. Maaari '
            'din silang magpadala ng Mobile Crisis Response Team.',
    'hotline.sdaocl.call': 'Tumawag sa 1-888-724-7240',
    'hotline.crisistext.name': 'Crisis Text Line',
    'hotline.crisistext.desc':
        'Mas gusto mong mag-type kaysa magsalita? Mag-text sa sinanay na volunteer tungkol '
            'sa kahit ano. Libre, 24/7, at kompidensyal.',
    'hotline.crisistext.sms': 'I-text ang HOME sa 741741',
    'hotline.trevor.name': 'The Trevor Project',
    'hotline.trevor.desc':
        'Suporta sa krisis at pag-iwas sa pagpapatiwakal para sa LGBTQ+ na kabataan, 24/7. '
            'Karapat-dapat kang seryosohin.',
    'hotline.trevor.call': 'Tumawag sa 1-866-488-7386',
    'hotline.trevor.sms': 'I-text ang START sa 678678',
    'hotline.sandyhook.name': 'Say Something Anonymous Reporting',
    'hotline.sandyhook.desc':
        'Anonymous na paraan para iulat ang banta, armas, o taong maaaring nasa panganib — '
            'mga crisis counselor ang sasagot. Para sa “may nag-aalala ako sa kaklase ko,” '
            'hindi lang sa emergency.',
    'hotline.sandyhook.call': 'Tumawag sa 1-844-5-SAYNOW',
    'hotline.pusdtip.name': 'PUSD “See Something, Say Something” Tip Line',
    'hotline.pusdtip.desc':
        '24-oras na anonymous na tip line ng Poway Unified, binabantayan ng law '
            'enforcement, para sa banta at isyu sa kaligtasan ng paaralan. Nasa likod ng '
            'student ID mo ang numero.',
    'hotline.pusdtip.call': 'Tumawag sa 1-844-PUSD-TIP',

    'settings.title': 'Mga Setting',
    'settings.safety': 'Kaligtasan',
    'settings.getHelp': 'Kumuha ng tulong ngayon',
    'settings.getHelpSub':
        'Mga counselor sa Westview, crisis line, at paano iulat ang isyu sa kaligtasan. '
            'Gumagana offline.',
    'settings.quickExit': 'Mabilisang paglabas',
    'settings.quickExitSub':
        'Pindutin nang matagal ang Help button para agad lumabas sa app. Walang natitira sa '
            'screen ng tiningnan mo.',
    'settings.hideRecents': 'Itago ang preview sa app switcher',
    'settings.hideRecentsSub':
        'Hindi ipapakita ang huling screen sa listahan ng recent apps (Android).',
    'settings.language': 'Wika',
    'settings.languageSub': 'Naaangkop sa Tulong, Mga Setting at navigation.',
    'settings.privacy': 'Privacy at data',
    'settings.about': 'Tungkol sa app na ito',

    'privacy.title': 'Ang iyong privacy',
    'privacy.intro':
        'Maaaring magpadala ang app na ito ng dalawang bagay sa server ng paaralan, at wala '
            'nang iba:',
    'privacy.bullet1':
        '• Anonymous na bilang ng paggamit — kung aling screen ang binuksan at kung '
            'nagtagumpay ang refresh. Walang pangalan o account.',
    'privacy.bullet2':
        '• Crash report — ang error text, na tinanggal ang anumang itina-type mo sa '
            'Settings, para maayos ito.',
    'privacy.never':
        'Hindi nito kinokolekta ang pangalan, student ID, contacts, lokasyon, o advertising '
            'identifier, at wala itong ibinabahagi sa third party. Walang third-party '
            'analytics.',
    'privacy.offUntil':
        'Naka-off ang dalawa maliban kung buksan mo, at mababago mo ito anumang oras sa '
            'Settings ▸ Privacy.',
    'privacy.dontShare': 'Huwag ibahagi',
    'privacy.share': 'Ibahagi nang anonymous',
    'settings.notifications':
        'Mga abiso',
    'settings.notificationsSub':
        'Payagan ang Westview HS na magpadala ng abiso',
    'settings.liveActivity':
        'Live na aktibidad',
    'settings.liveOn':
        'Palagiang abiso na may countdown hanggang matapos ang kasalukuyang period',
    'settings.liveOff':
        'Buksan ang abiso para magamit ang live na aktibidad',
    'settings.privacyData':
        'Privacy at data',
    'settings.analytics':
        'Anonymous na estadistika ng paggamit',
    'settings.analyticsSub':
        'Bilang ng mga screen na binuksan at kung nagtagumpay ang refresh. Hindi ka tinutukoy.',
    'settings.crash':
        'Mga crash report',
    'settings.crashSub':
        'Error text at stack trace kapag nagka-error ang app, para maayos ito. Hindi ka tinutukoy.',
    'settings.collectTitle':
        'Ano ang kinokolekta namin (at hindi)',
    'settings.collectBody':
        'Naka-off ang dalawang switch sa itaas maliban kung binuksan mo. Kapag bukas, nagpapadala ang app ng anonymous na bilang ng paggamit at crash report para maayos ito — tinanggal muna ang anumang itina-type mo sa Settings. Hindi nito kinokolekta ang pangalan, student ID, contacts, lokasyon, o advertising identifier. Sa server ng paaralan lang napupunta ang mga report.',
    'settings.savedContent':
        'Naka-save na content',
    'settings.clear':
        'Burahin ang naka-save na content',
    'settings.clearSub':
        'Tinatanggal ang mga kalendaryo, menu ng tanghalian at nutrition data na naka-save para sa offline. Magda-download muli kapag binuksan mo.',
    'settings.cleared':
        'Nabura ang naka-save na content',
    'settings.classDetails':
        'Detalye ng klase',
    'settings.showTeacher':
        'Ipakita ang teacher',
    'settings.showTeacherSub':
        'Ipakita ang teacher sa iskedyul, abiso at widget',
    'settings.showRoom':
        'Ipakita ang room number',
    'settings.showRoomSub':
        'Ipakita ang room sa iskedyul, abiso at widget',
    'settings.myClasses':
        'Aking mga klase',
    'settings.resetClasses':
        'I-reset ang lahat ng pangalan ng klase',
    'settings.resetTitle':
        'I-reset ang mga pangalan?',
    'settings.resetBody':
        'Tinatanggal nito ang lahat ng pangalan, teacher at room na inilagay mo.',
    'settings.reset':
        'I-reset',
    'settings.tapToAdd':
        'I-tap para magdagdag ng pangalan, teacher o room',
    'settings.editClass':
        'Pangalan ng klase',
    'settings.leaveEmpty':
        'Iwanang blangko para mapanatili ang kasalukuyang pangalan',
    'settings.teacher':
        'Teacher',
    'settings.room':
        'Room number',
    'settings.clearField':
        'Burahin',
    'settings.cancel':
        'Kanselahin',
    'settings.save':
        'I-save',
    'settings.notCrisis':
        'Hindi serbisyo para sa krisis ang app na ito at walang nagbabantay dito. Kung ikaw o ang iba ay nasa panganib, tumawag sa 911. Sa emosyonal na krisis, tumawag o mag-text sa 988.',
    'settings.verified':
        'Maaaring luma o mali ang iskedyul, menu at link. Palaging i-verify sa opisina ng paaralan ang mga sensitibo sa oras na impormasyon. Huling sinuri ang contacts ng counseling noong Nobyembre 2025; ang counseling office at website ng paaralan ang opisyal na pinagmulan.',
    'settings.langLabel':
        'Wika',
    'settings.langSystem':
        'Default ng system',
    'schedule.monFri':
        'Lun/Biy',
    'schedule.tueThu':
        'Mar/Huw',
    'schedule.wed':
        'Miy',
    'schedule.noActivePeriod':
        'Walang aktibong period',
    'schedule.now':
        'Ngayon',
    'schedule.endsAt': 'matatapos nang',
    'schedule.special':
        'May espesyal na iskedyul ngayon',
    'schedule.mayNotBeAccurate':
        'Hindi maabot ang server ng iskedyul, kaya maaaring hindi tumpak ang iskedyul ngayong araw.',
    'schedule.dismiss':
        'Isara',
    'schedule.checking':
        'Sinusuri ang update sa iskedyul',
    'schedule.settings':
        'Mga Setting',
    'schedule.help':
        'Tulong',
    'schedule.helpTooltip':
        'Kumuha ng tulong ngayon. Pindutin nang matagal para mabilis na lumabas sa app kung ayaw mong makita ang screen na ito.',
    'common.selected':
        'Napili',
    'common.refresh': 'I-refresh',
    'common.dismiss': 'Isara',
    'common.retry': 'Subukan muli',
    'newsletter.weekly': 'Lingguhang Newsletter',
    'newsletter.counseling': 'Newsletter ng Counseling',
    'newsletter.den': 'Mga Anunsyo ng Den',
    'publications.nexus': 'Westview Nexus',
    'publications.newscast': 'Westview Newscast',
    'web.errorTitle': 'Hindi mabuksan ang pahinang ito',
    'web.errorBody': 'Hindi na-load ang pahina. Suriin ang koneksyon at subukan muli.',
    'web.loading': 'Naglo-load ng pahina…',
    'web.stale': 'Hindi na-refresh — ipinapakita pa rin ang huling na-load na pahina.',
    'calendar.tabSchool': 'Kalendaryo ng Paaralan',
    'calendar.tabAthletics': 'Atletika',
    'calendar.tabLunch': 'Tanghalian sa Paaralan',
    'calendar.errorTitle': 'Hindi ma-load ang mga event',
    'calendar.errorBody': 'Hindi maabot ang calendar server. Suriin ang koneksyon at subukan muli.',
    'calendar.loading': 'Naglo-load ng mga event…',
    'calendar.emptyTitle': 'Walang darating na event',
    'calendar.emptyBody': 'Walang naka-iskedyul sa kalendaryong ito ngayon. Hilahin pababa para i-refresh.',
    'calendar.savedCopy': 'Naka-save na kopya mula',
    'calendar.untitled': 'Event na walang pamagat',
    'calendar.description': 'Paglalarawan',
    'calendar.noDescription': 'Walang ibinigay na paglalarawan.',
    'calendar.allDay': 'Buong araw',
    'calendar.today': 'Ngayon',
    'calendar.yesterday': 'Kahapon',
    'calendar.tomorrow': 'Bukas',
    'calendar.weekdays': 'Lunes,Martes,Miyerkules,Huwebes,Biyernes,Sabado,Linggo',
    'calendar.am': 'AM',
    'calendar.pm': 'PM',
    'schedule.refresh': 'Nire-refresh ang iskedyul…',
    'settings.langPickTitle': 'Wika ng app',
    'web.retry': 'Subukan muli',
    'common.loading': 'Naglo-load…',
    'common.errorTitle': 'Hindi ma-load ngayon',
    'help.iconTooltip': 'Humingi ng tulong ngayon',
    'help.iconTooltipQuickExit': '%s (mahabang pindot para agad lumabas sa app)',
    'lunch.errorTitle': 'Hindi ma-load ang menu',
    'lunch.errorBody': 'Hindi maabot ang menu server. Suriin ang koneksyon at subukan muli.',
    'lunch.loading': 'Naglo-load ng menu…',
    'lunch.emptyTitle': 'Walang naka-publish na menu',
    'lunch.emptyBody': 'Wala pang naka-publish na menu ngayong buwan. Hilahin pababa para i-refresh.',
    'lunch.savedCopy': 'Naka-save na menu mula',
    'lunch.noSchool': 'Walang pasok',
    'lunch.entrees': 'Pangunahing Putihe',
    'lunch.vegetables': 'Gulay',
    'lunch.fruit': 'Prutas at Juice',
    'lunch.milk': 'Pagpipilian ng Gatas',
    'lunch.noFactsFor': 'Walang nutrition facts para sa %s',
    'lunch.servingSize': 'Serving size',
    'lunch.oneServing': '1 serving',
    'lunch.noNutrition': 'Walang detalyadong nutrition data.',
    'lunch.nutritionFacts': 'Nutrition Facts',
    'lunch.calories': 'Calories',
    'lunch.totalFat': 'Total fat',
    'lunch.saturatedFat': 'Saturated fat',
    'lunch.transFat': 'Trans fat',
    'lunch.cholesterol': 'Cholesterol',
    'lunch.sodium': 'Sodium',
    'lunch.carbs': 'Carbohydrates',
    'lunch.fiber': 'Dietary fiber',
    'lunch.sugars': 'Sugars',
    'lunch.protein': 'Protein',
    'help.counselor.callA11y': 'Tumawag kay %s',
    'help.counselor.emailA11y': 'I-email si %s',
    'help.counselor.emailSubject': 'Tanong ng estudyante para sa aking counselor',
    'help.counselor.careerTitle': 'Gabay sa kolehiyo at karera',
    'help.counselor.careerRole': 'College & Career Guidance Technician',
    'settings.roomShort': 'Rm',
  },
};
