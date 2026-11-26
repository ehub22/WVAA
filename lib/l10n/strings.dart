import 'package:flutter/widgets.dart';

import '../settings.dart';

/// Languages supported across the app's own UI.
///
/// Every screen drawn by Flutter is translated here, including Get help
/// (counselors, crisis lines, and reporting), the disclaimers, navigation, and
/// Settings. Embedded WebViews (newsletters and publications) load Westview's
/// external pages directly, so they stay in whatever language those pages use.
enum AppLanguage {
  system('system', 'System default', 'Sistema'),
  english('en', 'English', 'English'),
  spanish('es', 'Español', 'Español'),
  chinese('zh', '简体中文', '中文'),
  tagalog('tl', 'Filipino', 'Filipino');

  const AppLanguage(this.code, this.nativeName, this.shortName);

  /// BCP-47 tag; [system] resolves against the phone's current locale.
  final String code;

  /// Language name written in that language for the picker.
  final String nativeName;

  /// Shorter label used in compact spots.
  final String shortName;

  /// Shows each language in all four supported scripts so you can still find
  /// your language if the app got switched to one you don't read.
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

  /// Resolves which language map to use for [deviceLocale].
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

/// App string lookup table.
///
/// I kept this as a plain Dart map instead of setting up ARB code generation
/// because there are only around 200 keys, `flutter test` can check key parity
/// directly without a `build_runner` step, and falling back to English (and
/// then the key name) means a typo shows up in tests instead of rendering a
/// blank button on the Get help screen.
class AppStrings {
  const AppStrings(this.languageCode);

  /// Resolved BCP-47 tag (`en`, `es`, `zh`, `tl`).
  final String languageCode;

  static AppStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return forTag(AppSettings.instance.language.resolve(locale));
  }

  static AppStrings forTag(String tag) => AppStrings(tag);

  /// Looks up [key], falling back to English and then the raw key name so
  /// missing keys fail loudly in tests instead of showing up blank.
  String operator [](String key) =>
      _catalog[languageCode]?[key] ?? _catalog['en']![key] ?? key;

  /// Returns true if [languageCode] doesn't define [key] (used by l10n tests).
  bool isMissing(String key) => !(_catalog[languageCode]?.containsKey(key) ?? false);

  /// Safety and disclaimer keys that `l10n_test.dart` checks in every language.
  static List<String> get criticalKeys => _catalog['en']!
      .keys
      .where((k) => k.startsWith('help.') || k.startsWith('disclaimer.'))
      .toList(growable: false);

  static Map<String, Map<String, String>> get catalog => _catalog;
}

// ===========================================================================
// String maps (en, es, zh, tl)
// Note: Chinese (`zh`) strings should get a pass from a fluent speaker when
// available; `tools/check_strings.py` enforces formatting and key parity.
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
    'common.copyNumber': 'Copy this number',
    'sms.confirmTitle': 'Send this text?',
    'sms.openApp': 'Open Messages',
    'sms.editNote':
        'Your messaging app will open with this keyword filled in so you can '
        'review or add to it before sending.',

    'disclaimer.short':
        'Not a Poway Unified app. Built independently by students and not '
        'sponsored or endorsed by Poway Unified School District or Westview '
        'High School.',
    'disclaimer.title': 'This app is not part of Poway Unified',
    'disclaimer.plain':
        'Westview HS (WVAA) is an independent app built by students rather '
        'than Poway Unified School District or Westview High School. Because '
        'the school does not run or review this app, schedules, links, or '
        'contacts shown here could be out of date, so confirm important '
        'details with the school office, your counselor, or Westview\'s '
        'website.',
    'disclaimer.crisis':
        'This app is not a crisis service and is not monitored. If you or '
        'someone else is in danger, call 911. During an emotional crisis, call '
        'or text 988.',
    'disclaimer.translationNote':
        'Translated summaries are included to make this notice easier to read, '
        'while the official English and Spanish text required by the district '
        'remains the binding version.',

    'help.title': 'Get help',
    'help.emergency.title': 'In immediate danger?',
    'help.emergency.body':
        'Call 911 right away if you or someone else is in danger of being hurt '
        'and needs immediate help.',
    'help.emergency.call': 'Call 911',
    'help.emergency.note':
        'If you are unsure whether a situation is an emergency, call or text '
        '988 so a counselor can help you figure out what to do next.',

    'help.counselor.title': 'Talk to a counselor at Westview',
    'help.counselor.body':
        'Westview counselors are available in the Wolverine Center during '
        'school hours. Students can stop by in person, ask a teacher for a '
        'pass, or email their counselor directly without having to explain '
        'everything in the message.',
    'help.counselor.callOffice': 'Call the office',
    'help.counselor.website': 'Counseling website',
    'help.counselor.find': 'Find your counselor',
    'help.counselor.byLast': 'Assigned by the first letter of your last name.',
    'help.counselor.career': 'College & career questions',
    'help.counselor.verified':
        'Counselor assignments can change during the school year, so check '
        'Westview\'s website or the counseling office if your last name does '
        'not match the list below. (Checked November 2025.)',

    'help.crisis.title': '24/7 free and confidential crisis lines',
    'help.crisis.call': 'Call',
    'help.crisis.text': 'Text',
    'help.crisis.deaf':
        'If you are deaf, hard of hearing, or unable to speak out loud, every '
        'service below can also be reached by text or online. Both 988 and '
        'Crisis Text Line support texting directly, while the San Diego County '
        'line accepts 711 relay calls.',

    'help.report.title': 'Report a safety concern',
    'help.report.body':
        'If you are worried about a classmate, a threat, a weapon, or '
        'something posted online, tell a trusted adult such as a teacher, '
        'counselor, coach, or parent. Concerns can also be reported '
        'anonymously through these lines:',
    'help.report.note':
        'You do not need complete proof before reporting a concern, because '
        'trained staff review each tip to see what support is needed.',

    'help.about.title': 'About this app',

    'hotline.988.name': '988 Suicide & Crisis Lifeline',
    'hotline.988.desc':
        'Free, confidential 24/7 support by phone or text for anyone '
        'experiencing emotional distress or a suicidal crisis.',
    'hotline.988.call': 'Call 988',
    'hotline.988.sms': 'Text 988',
    'hotline.sdaocl.name': 'San Diego Access & Crisis Line',
    'hotline.sdaocl.desc':
        'San Diego County\'s 24/7 line for mental health or substance-use '
        'crises affecting you or someone you know, with free interpreters in '
        'over 200 languages and mobile crisis response teams when needed.',
    'hotline.sdaocl.call': 'Call 1-888-724-7240',
    'hotline.crisistext.name': 'Crisis Text Line',
    'hotline.crisistext.desc':
        'Connects you by text with a trained crisis counselor at any hour if '
        'typing is easier than speaking on a call. Free and confidential.',
    'hotline.crisistext.sms': 'Text HOME to 741741',
    'hotline.trevor.name': 'The Trevor Project',
    'hotline.trevor.desc':
        'Free, confidential 24/7 crisis and suicide-prevention support for '
        'LGBTQ+ youth by phone or text.',
    'hotline.trevor.call': 'Call 1-866-488-7386',
    'hotline.trevor.sms': 'Text START to 678678',
    'hotline.sandyhook.name': 'Say Something Anonymous Reporting',
    'hotline.sandyhook.desc':
        'Anonymous reporting line answered by crisis counselors for threats, '
        'weapons, or concern that a classmate may be at risk of harm.',
    'hotline.sandyhook.call': 'Call 1-844-5-SAYNOW',
    'hotline.pusdtip.name': 'PUSD "See Something, Say Something" Tip Line',
    'hotline.pusdtip.desc':
        'Poway Unified\'s 24-hour anonymous tip line monitored by law '
        'enforcement for campus threats and safety concerns (also printed on '
        'the back of student IDs).',
    'hotline.pusdtip.call': 'Call 1-844-PUSD-TIP',

    'settings.title': 'Settings',
    'settings.safety': 'Safety',
    'settings.getHelp': 'Get help now',
    'settings.getHelpSub':
        'Westview counselors, 24/7 crisis lines, and anonymous safety '
        'reporting. Available offline.',
    'settings.quickExit': 'Quick exit',
    'settings.quickExitSub':
        'Hold down the Help button to close this screen and move the app to '
        'the background right away.',
    'settings.hideRecents': 'Hide preview in app switcher',
    'settings.hideRecentsSub':
        'Blanks out the app\'s thumbnail in Android\'s recent-apps list while '
        'in the background.',
    'settings.language': 'Language',
    'settings.languageSub': 'Applies to Help, Settings, and navigation.',
    'settings.privacy': 'Privacy & data',
    'settings.about': 'About this app',

    'privacy.title': 'Your privacy',
    'privacy.intro':
        'If enabled, this app sends only two kinds of anonymous data to the '
        'school server:',
    'privacy.bullet1':
        '• Anonymous usage counts: which tabs are opened and whether refreshes '
        'succeed, without names or accounts.',
    'privacy.bullet2':
        '• Crash reports: error details with any class names, teachers, or '
        'rooms typed into Settings removed before sending.',
    'privacy.never':
        'The app does not use third-party analytics and never collects names, '
        'student IDs, contacts, location, or advertising identifiers.',
    'privacy.offUntil':
        'Both options stay off unless turned on, and either setting can be '
        'changed anytime under Settings > Privacy & data.',
    'privacy.dontShare': 'Don\'t share',
    'privacy.share': 'Share anonymously',
    'settings.notifications': 'Notifications',
    'settings.notificationsSub': 'Allow Westview HS to send notifications',
    'settings.liveActivity': 'Live activity',
    'settings.liveOn':
        'Ongoing notification with a countdown to the end of the current '
        'period',
    'settings.liveOff': 'Turn notifications on to use the live activity',
    'settings.privacyData': 'Privacy & data',
    'settings.analytics': 'Anonymous usage statistics',
    'settings.analyticsSub':
        'Counts which screens open and whether refreshes succeed, without '
        'identifying you.',
    'settings.crash': 'Crash reports',
    'settings.crashSub':
        'Sends error details and stack traces when something crashes so bugs '
        'can be fixed, without identifying you.',
    'settings.collectTitle': 'What this app collects',
    'settings.collectBody':
        'Both switches stay off until enabled. When turned on, the app sends '
        'anonymous usage counts and crash reports to the school server after '
        'stripping anything typed into My classes, and it never collects '
        'names, student IDs, contacts, location, or advertising IDs.',
    'settings.savedContent': 'Saved content',
    'settings.clear': 'Clear saved content',
    'settings.clearSub':
        'Removes cached calendars, lunch menus, and nutrition data stored for '
        'offline viewing so they download fresh next time.',
    'settings.cleared': 'Saved content cleared',
    'settings.classDetails': 'Class details',
    'settings.showTeacher': 'Show teacher',
    'settings.showTeacherSub':
        'Show teacher names in the schedule, notification, and widget',
    'settings.showRoom': 'Show room number',
    'settings.showRoomSub':
        'Show room numbers in the schedule, notification, and widget',
    'settings.myClasses': 'My classes',
    'settings.resetClasses': 'Reset all class names',
    'settings.resetTitle': 'Reset class names?',
    'settings.resetBody':
        'This clears every custom class name, teacher, and room number you '
        'entered.',
    'settings.reset': 'Reset',
    'settings.tapToAdd': 'Tap to add a class name, teacher, or room',
    'settings.editClass': 'Class name',
    'settings.leaveEmpty': 'Leave empty to keep the default period name',
    'settings.teacher': 'Teacher',
    'settings.room': 'Room number',
    'settings.clearField': 'Clear',
    'settings.cancel': 'Cancel',
    'settings.save': 'Save',
    'settings.notCrisis':
        'This app is not a crisis service and is not monitored. If you or '
        'someone else is in danger, call 911. During an emotional crisis, call '
        'or text 988.',
    'settings.verified':
        'Because schedules, menus, and links can change during the year, '
        'confirm time-sensitive details with the school office. Counselor '
        'contacts were last checked in November 2025 against Westview\'s '
        'counseling webpage.',
    'settings.langLabel': 'Language',
    'settings.langSystem': 'System default',
    'schedule.monFri': 'Mon/Fri',
    'schedule.tueThu': 'Tue/Thu',
    'schedule.wed': 'Wed',
    'schedule.noActivePeriod': 'No active period',
    'schedule.now': 'Now',
    'schedule.endsAt': 'ends at',
    'schedule.special': 'A special schedule is in effect today',
    'schedule.mayNotBeAccurate':
        'Could not reach the special-schedule server, so today\'s schedule '
        'might be out of date.',
    'schedule.dismiss': 'Dismiss',
    'schedule.checking': 'Checking for schedule updates',
    'schedule.settings': 'Settings',
    'schedule.help': 'Help',
    'schedule.helpTooltip':
        'Get help now. Hold down this button to close the app right away.',
    'common.selected': 'Selected',
    'common.refresh': 'Refresh page',
    'common.dismiss': 'Dismiss',
    'common.retry': 'Try again',
    'newsletter.weekly': 'Weekly Newsletter',
    'newsletter.counseling': 'Counseling Newsletters',
    'newsletter.den': 'Den Announcements',
    'publications.nexus': 'Westview Nexus',
    'publications.newscast': 'Westview Newscast',
    'web.errorTitle': 'Couldn\'t open this page',
    'web.errorBody':
        'The page could not be loaded. Check your connection and try again.',
    'web.loading': 'Loading page…',
    'web.stale': 'Refresh failed, so the previously loaded page is still shown.',
    'calendar.tabSchool': 'School Calendar',
    'calendar.tabAthletics': 'Athletics',
    'calendar.tabLunch': 'School Lunches',
    'calendar.errorTitle': 'Couldn\'t load calendar events',
    'calendar.errorBody':
        'Could not reach the calendar server. Check your connection and try '
        'again.',
    'calendar.loading': 'Loading events…',
    'calendar.emptyTitle': 'No upcoming events',
    'calendar.emptyBody':
        'Nothing is scheduled on this calendar right now. Pull down to '
        'refresh.',
    'calendar.savedCopy': 'Saved copy from',
    'calendar.untitled': 'Untitled event',
    'calendar.description': 'Description',
    'calendar.noDescription': 'No description provided.',
    'calendar.allDay': 'All day',
    'calendar.today': 'Today',
    'calendar.yesterday': 'Yesterday',
    'calendar.tomorrow': 'Tomorrow',
    'calendar.weekdays':
        'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
    'calendar.am': 'AM',
    'calendar.pm': 'PM',
    'schedule.refresh': 'Refreshing schedule…',
    'settings.langPickTitle': 'App language',
    'web.retry': 'Try again',
    'common.loading': 'Loading…',
    'common.errorTitle': 'Can\'t load this right now',
    'help.iconTooltip': 'Get help now',
    'help.iconTooltipQuickExit': '%s (hold down to leave the app right away)',
    'lunch.errorTitle': 'Couldn\'t load the lunch menu',
    'lunch.errorBody':
        'Could not reach the menu server. Check your connection and try again.',
    'lunch.loading': 'Loading the menu…',
    'lunch.emptyTitle': 'No lunch menu published',
    'lunch.emptyBody':
        'This month\'s lunch menu has not been posted yet. Pull down to '
        'refresh.',
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
    'common.copyNumber': 'Copiar este número',
    'sms.confirmTitle': '¿Enviar este mensaje?',
    'sms.openApp': 'Abrir Mensajes',
    'sms.editNote':
        'Se abrirá tu aplicación de mensajes con esta palabra clave lista para '
        'que puedas revisarla o agregar más texto antes de enviarla.',

    'disclaimer.short':
        'No es una aplicación de Poway Unified. Fue creada de forma '
        'independiente por estudiantes y no está patrocinada ni avalada por el '
        'Distrito Escolar Unificado de Poway ni por Westview High School.',
    'disclaimer.title': 'Esta aplicación no forma parte de Poway Unified',
    'disclaimer.plain':
        'Westview HS (WVAA) es una aplicación independiente creada por '
        'estudiantes y no por el Distrito Escolar Unificado de Poway ni '
        'Westview High School. Como la escuela no la administra ni la revisa, '
        'los horarios, enlaces o contactos pueden no estar al día, así que '
        'confirma los detalles importantes con la oficina escolar, tu '
        'consejero o el sitio web de Westview.',
    'disclaimer.crisis':
        'Esta aplicación no es un servicio de crisis y nadie la monitorea. Si '
        'tú o alguien más está en peligro, llama al 911. Durante una crisis '
        'emocional, llama o envía un texto al 988.',
    'disclaimer.translationNote':
        'Los resúmenes traducidos se incluyen para facilitar la lectura, pero '
        'el texto oficial en inglés y español exigido por el distrito sigue '
        'siendo la versión vigente.',

    'help.title': 'Ayuda',
    'help.emergency.title': '¿Peligro inmediato?',
    'help.emergency.body':
        'Llama al 911 de inmediato si tú o alguien más corre peligro de salir '
        'herido y necesita ayuda urgente.',
    'help.emergency.call': 'Llamar al 911',
    'help.emergency.note':
        'Si no estás seguro de si una situación es una emergencia, llama o '
        'envía un texto al 988 para que un consejero te ayude a decidir qué '
        'hacer.',

    'help.counselor.title': 'Habla con un consejero de Westview',
    'help.counselor.body':
        'Los consejeros de Westview están disponibles en el Wolverine Center '
        'durante el horario escolar. Puedes pasar en persona, pedirle un pase '
        'a un maestro o enviar un correo directo a tu consejero sin tener que '
        'explicar todo en el mensaje.',
    'help.counselor.callOffice': 'Llamar a la oficina',
    'help.counselor.website': 'Sitio de consejería',
    'help.counselor.find': 'Encuentra a tu consejero',
    'help.counselor.byLast': 'Asignado según la primera letra de tu apellido.',
    'help.counselor.career': 'Preguntas sobre universidad y carrera',
    'help.counselor.verified':
        'Las asignaciones de consejeros pueden cambiar durante el año escolar, '
        'así que revisa el sitio web de Westview o consulta en la oficina de '
        'consejería si tu apellido no coincide con la lista. (Revisado en '
        'noviembre de 2025.)',

    'help.crisis.title': 'Líneas de crisis gratuitas y confidenciales 24/7',
    'help.crisis.call': 'Llamar',
    'help.crisis.text': 'Texto',
    'help.crisis.deaf':
        'Si eres sordo, tienes dificultad auditiva o no puedes hablar en voz '
        'alta, todos los servicios de abajo también atienden por texto o en '
        'línea. El 988 y Crisis Text Line funcionan directamente por mensaje '
        'de texto, mientras que la línea del Condado de San Diego acepta '
        'llamadas de relevo marcando el 711.',

    'help.report.title': 'Reportar un problema de seguridad',
    'help.report.body':
        'Si te preocupa un compañero, una amenaza, un arma o algo publicado en '
        'línea, avísale a un adulto de confianza como un maestro, consejero, '
        'entrenador o familiar. También puedes reportarlo de forma anónima en '
        'estas líneas:',
    'help.report.note':
        'No necesitas tener pruebas completas antes de hacer un reporte, ya '
        'que personal capacitado revisa cada aviso para ver qué apoyo hace '
        'falta.',

    'help.about.title': 'Sobre esta aplicación',

    'hotline.988.name': 'Línea 988 de Prevención del Suicidio y Crisis',
    'hotline.988.desc':
        'Apoyo gratuito y confidencial las 24 horas por teléfono o mensaje de '
        'texto para cualquier persona con angustia emocional o crisis suicida.',
    'hotline.988.call': 'Llamar al 988',
    'hotline.988.sms': 'Texto al 988',
    'hotline.sdaocl.name': 'Línea de Acceso y Crisis de San Diego',
    'hotline.sdaocl.desc':
        'Línea 24/7 del Condado de San Diego para crisis de salud mental o '
        'consumo de sustancias que te afecten a ti o a un conocido, con '
        'intérpretes gratuitos en más de 200 idiomas y equipos móviles de '
        'respuesta cuando se necesitan.',
    'hotline.sdaocl.call': 'Llamar al 1-888-724-7240',
    'hotline.crisistext.name': 'Crisis Text Line (línea de texto)',
    'hotline.crisistext.desc':
        'Te comunica por mensaje de texto con un consejero capacitado a '
        'cualquier hora si te resulta más fácil escribir que hablar por '
        'teléfono. Gratis y confidencial.',
    'hotline.crisistext.sms': 'Envía HOME al 741741',
    'hotline.trevor.name': 'The Trevor Project',
    'hotline.trevor.desc':
        'Apoyo gratuito y confidencial las 24 horas en situaciones de crisis y '
        'prevención del suicidio para jóvenes LGBTQ+, por teléfono o texto.',
    'hotline.trevor.call': 'Llamar al 1-866-488-7386',
    'hotline.trevor.sms': 'Envía START al 678678',
    'hotline.sandyhook.name': 'Reportes anónimos Say Something',
    'hotline.sandyhook.desc':
        'Línea anónima atendida por consejeros de crisis para reportar '
        'amenazas, armas o preocupación por un compañero que pueda estar en '
        'riesgo.',
    'hotline.sandyhook.call': 'Llamar al 1-844-5-SAYNOW',
    'hotline.pusdtip.name':
        'Línea de reportes "See Something, Say Something" de PUSD',
    'hotline.pusdtip.desc':
        'Línea anónima de 24 horas de Poway Unified monitoreada por las '
        'autoridades para amenazas y problemas de seguridad escolar (también '
        'impresa detrás de la credencial estudiantil).',
    'hotline.pusdtip.call': 'Llamar al 1-844-PUSD-TIP',

    'settings.title': 'Ajustes',
    'settings.safety': 'Seguridad',
    'settings.getHelp': 'Obtener ayuda ahora',
    'settings.getHelpSub':
        'Consejeros de Westview, líneas de crisis 24/7 y reportes anónimos de '
        'seguridad. Funciona sin conexión.',
    'settings.quickExit': 'Salida rápida',
    'settings.quickExitSub':
        'Mantén presionado el botón de Ayuda para cerrar esta pantalla y '
        'enviar la aplicación a segundo plano al instante.',
    'settings.hideRecents': 'Ocultar vista previa en apps recientes',
    'settings.hideRecentsSub':
        'Oculta la miniatura de la aplicación en la lista de apps recientes de '
        'Android mientras está en segundo plano.',
    'settings.language': 'Idioma',
    'settings.languageSub': 'Se aplica a Ayuda, Ajustes y la navegación.',
    'settings.privacy': 'Privacidad y datos',
    'settings.about': 'Sobre esta aplicación',

    'privacy.title': 'Tu privacidad',
    'privacy.intro':
        'Si lo activas, esta aplicación envía solo dos tipos de datos anónimos '
        'al servidor escolar:',
    'privacy.bullet1':
        '• Conteos de uso anónimos: qué pestañas se abren y si las '
        'actualizaciones funcionan, sin nombres ni cuentas.',
    'privacy.bullet2':
        '• Reportes de fallos: detalles del error después de borrar cualquier '
        'clase, maestro o salón escrito en Ajustes.',
    'privacy.never':
        'La aplicación no usa analítica de terceros y nunca recopila nombres, '
        'números de estudiante, contactos, ubicación ni identificadores '
        'publicitarios.',
    'privacy.offUntil':
        'Ambas opciones permanecen desactivadas a menos que las actives, y '
        'puedes cambiarlas cuando quieras en Ajustes > Privacidad y datos.',
    'privacy.dontShare': 'No compartir',
    'privacy.share': 'Compartir de forma anónima',
    'settings.notifications': 'Notificaciones',
    'settings.notificationsSub':
        'Permitir que Westview HS envíe notificaciones',
    'settings.liveActivity': 'Actividad en curso',
    'settings.liveOn':
        'Notificación continua con cuenta regresiva hasta el final del período '
        'actual',
    'settings.liveOff':
        'Activa las notificaciones para usar la actividad en curso',
    'settings.privacyData': 'Privacidad y datos',
    'settings.analytics': 'Estadísticas de uso anónimas',
    'settings.analyticsSub':
        'Cuenta qué pantallas se abren y si las actualizaciones funcionan, sin '
        'identificarte.',
    'settings.crash': 'Reportes de fallos',
    'settings.crashSub':
        'Envía detalles del error y rastros de pila cuando algo falla para '
        'poder corregirlo, sin identificarte.',
    'settings.collectTitle': 'Qué recopila esta aplicación',
    'settings.collectBody':
        'Ambos interruptores permanecen apagados hasta que los actives. Cuando '
        'están activos, la aplicación envía conteos de uso anónimos y reportes '
        'de fallos al servidor escolar después de quitar lo que hayas escrito '
        'en Mis clases, y nunca recopila nombres, ID estudiantil, contactos, '
        'ubicación ni ID publicitarios.',
    'settings.savedContent': 'Contenido guardado',
    'settings.clear': 'Borrar contenido guardado',
    'settings.clearSub':
        'Elimina calendarios, menús de almuerzo y datos nutricionales '
        'guardados para consulta sin conexión para que se descarguen de nuevo.',
    'settings.cleared': 'Contenido guardado borrado',
    'settings.classDetails': 'Datos de las clases',
    'settings.showTeacher': 'Mostrar maestro',
    'settings.showTeacherSub':
        'Mostrar nombres de maestros en el horario, la notificación y el '
        'widget',
    'settings.showRoom': 'Mostrar número de salón',
    'settings.showRoomSub':
        'Mostrar números de salón en el horario, la notificación y el widget',
    'settings.myClasses': 'Mis clases',
    'settings.resetClasses': 'Restablecer todos los nombres',
    'settings.resetTitle': '¿Restablecer los nombres?',
    'settings.resetBody':
        'Esto borra todos los nombres de clases, maestros y salones que '
        'ingresaste.',
    'settings.reset': 'Restablecer',
    'settings.tapToAdd': 'Toca para añadir clase, maestro o salón',
    'settings.editClass': 'Nombre de la clase',
    'settings.leaveEmpty':
        'Déjalo vacío para conservar el nombre predeterminado del período',
    'settings.teacher': 'Maestro',
    'settings.room': 'Número de salón',
    'settings.clearField': 'Borrar',
    'settings.cancel': 'Cancelar',
    'settings.save': 'Guardar',
    'settings.notCrisis':
        'Esta aplicación no es un servicio de crisis y nadie la monitorea. Si '
        'tú o alguien más está en peligro, llama al 911. Durante una crisis '
        'emocional, llama o envía un texto al 988.',
    'settings.verified':
        'Como los horarios, menús y enlaces pueden cambiar durante el año, '
        'confirma los detalles urgentes con la oficina escolar. Los contactos '
        'de consejería se verificaron en noviembre de 2025 en el sitio web de '
        'consejería de Westview.',
    'settings.langLabel': 'Idioma',
    'settings.langSystem': 'Predeterminado del sistema',
    'schedule.monFri': 'Lun/Vie',
    'schedule.tueThu': 'Mar/Jue',
    'schedule.wed': 'Mié',
    'schedule.noActivePeriod': 'Ningún período activo',
    'schedule.now': 'Ahora',
    'schedule.endsAt': 'termina a las',
    'schedule.special': 'Hoy aplica un horario especial',
    'schedule.mayNotBeAccurate':
        'No se pudo conectar con el servidor de horarios especiales, por lo '
        'que el horario de hoy podría no estar actualizado.',
    'schedule.dismiss': 'Cerrar',
    'schedule.checking': 'Buscando cambios de horario',
    'schedule.settings': 'Ajustes',
    'schedule.help': 'Ayuda',
    'schedule.helpTooltip':
        'Obtener ayuda ahora. Mantén presionado este botón para cerrar la '
        'aplicación al instante.',
    'common.selected': 'Seleccionado',
    'common.refresh': 'Actualizar',
    'common.dismiss': 'Descartar',
    'common.retry': 'Reintentar',
    'newsletter.weekly': 'Boletín semanal',
    'newsletter.counseling': 'Boletines de consejería',
    'newsletter.den': 'Anuncios del Den',
    'publications.nexus': 'Westview Nexus',
    'publications.newscast': 'Noticiero de Westview',
    'web.errorTitle': 'No se pudo abrir esta página',
    'web.errorBody':
        'No se pudo cargar la página. Revisa tu conexión e inténtalo de nuevo.',
    'web.loading': 'Cargando página…',
    'web.stale':
        'Falló la actualización, por lo que se sigue mostrando la página '
        'cargada anteriormente.',
    'calendar.tabSchool': 'Calendario escolar',
    'calendar.tabAthletics': 'Deportes',
    'calendar.tabLunch': 'Almuerzos escolares',
    'calendar.errorTitle': 'No se pudieron cargar los eventos',
    'calendar.errorBody':
        'No se pudo conectar con el servidor del calendario. Revisa tu '
        'conexión e inténtalo de nuevo.',
    'calendar.loading': 'Cargando eventos…',
    'calendar.emptyTitle': 'No hay eventos próximos',
    'calendar.emptyBody':
        'No hay eventos programados en este calendario ahora mismo. Desliza '
        'hacia abajo para actualizar.',
    'calendar.savedCopy': 'Copia guardada del',
    'calendar.untitled': 'Evento sin título',
    'calendar.description': 'Descripción',
    'calendar.noDescription': 'No se proporcionó descripción.',
    'calendar.allDay': 'Todo el día',
    'calendar.today': 'Hoy',
    'calendar.yesterday': 'Ayer',
    'calendar.tomorrow': 'Mañana',
    'calendar.weekdays':
        'lunes,martes,miércoles,jueves,viernes,sábado,domingo',
    'calendar.am': 'a. m.',
    'calendar.pm': 'p. m.',
    'schedule.refresh': 'Actualizando horario…',
    'settings.langPickTitle': 'Idioma de la aplicación',
    'web.retry': 'Reintentar',
    'common.loading': 'Cargando…',
    'common.errorTitle': 'No se puede cargar en este momento',
    'help.iconTooltip': 'Obtener ayuda ahora',
    'help.iconTooltipQuickExit':
        '%s (mantén presionado para salir de inmediato)',
    'lunch.errorTitle': 'No se pudo cargar el menú',
    'lunch.errorBody':
        'No se pudo conectar con el servidor del menú. Revisa tu conexión e '
        'inténtalo de nuevo.',
    'lunch.loading': 'Cargando el menú…',
    'lunch.emptyTitle': 'No hay menú publicado',
    'lunch.emptyBody':
        'Todavía no se ha publicado el menú de este mes. Desliza hacia abajo '
        'para actualizar.',
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
    'help.counselor.careerRole':
        'Técnica de orientación universitaria y profesional',
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
    'common.copyNumber': '复制此号码',
    'sms.confirmTitle': '要发送这条短信吗？',
    'sms.openApp': '打开信息',
    'sms.editNote':
        '系统会打开你的短信应用并预先填入该关键词，发送前你可以检查或补充内容。',

    'disclaimer.short':
        '非 Poway 联合学区官方应用。本应用由学生独立开发，未获 Poway 联合学区或 '
        'Westview 高中赞助或认可。',
    'disclaimer.title': '本应用不属于 Poway 联合学区',
    'disclaimer.plain':
        'Westview HS（WVAA）是由学生独立开发的应用，并非由 Poway 联合学区或 '
        'Westview 高中制作。由于学校不负责运营或审核本应用，这里显示的课表、链接或'
        '联系方式可能未及时更新，重要信息请向学校办公室、辅导员或 Westview 网站确认。',
    'disclaimer.crisis':
        '本应用不是危机干预服务，也没有人实时查看。如果你或他人面临危险，请拨打 911。'
        '遇到情绪危机时，请拨打或发送短信至 988。',
    'disclaimer.translationNote':
        '译文摘要仅为方便阅读提供；具有约束力的版本仍为学区要求的官方英文和西班牙文文本。',

    'help.title': '求助',
    'help.emergency.title': '有立即危险吗？',
    'help.emergency.body':
        '如果你或他人正面临受伤危险并需要紧急救助，请立即拨打 911。',
    'help.emergency.call': '拨打 911',
    'help.emergency.note':
        '如果你不确定当前情况是否属于紧急情况，请拨打或发短信至 988，辅导员会协助你判断下一步怎么做。',

    'help.counselor.title': '与 Westview 的辅导员联系',
    'help.counselor.body':
        '上课时间 Westview 辅导员都在 Wolverine Center。你可以直接前往、请老师开通行条，'
        '或直接发邮件给你的辅导员，邮件里不必一次把所有情况都写完。',
    'help.counselor.callOffice': '致电办公室',
    'help.counselor.website': '辅导网站',
    'help.counselor.find': '查找你的辅导员',
    'help.counselor.byLast': '按姓氏首字母分配。',
    'help.counselor.career': '升学与职业问题',
    'help.counselor.verified':
        '辅导员分工在学年中可能调整；如果你的姓氏不在下方列表中，请查询 Westview 网站'
        '或咨询辅导办公室。（核对时间：2025 年 11 月。）',

    'help.crisis.title': '24 小时免费保密危机热线',
    'help.crisis.call': '拨打',
    'help.crisis.text': '短信',
    'help.crisis.deaf':
        '如果你失聪、听力不便或无法出声通话，下列每项服务也都支持短信或在线联系。988 与 '
        'Crisis Text Line 可直接收发短信，圣地亚哥县热线也可拨打 711 通过中继服务接通。',

    'help.report.title': '报告安全隐忧',
    'help.report.body':
        '如果你担心某位同学、校园威胁、武器或网上看到的内容，请告诉老师、辅导员、教练或'
        '家长等可信赖的成年人，也可以通过以下渠道匿名报告：',
    'help.report.note':
        '报告前不需要掌握完整证据，受过训练的工作人员会核实每条线索并判断需要哪些支持。',

    'help.about.title': '关于本应用',

    'hotline.988.name': '988 自杀与危机生命线',
    'hotline.988.desc':
        '全天 24 小时通过电话或短信，为处于情绪困扰或自杀危机中的人提供免费、保密的支持。',
    'hotline.988.call': '拨打 988',
    'hotline.988.sms': '短信 988',
    'hotline.sdaocl.name': '圣地亚哥心理援助与危机热线',
    'hotline.sdaocl.desc':
        '圣地亚哥县 24 小时心理健康与物质使用危机热线，本人或关心他人均可拨打，提供 200 '
        '多种语言免费口译，并在需要时派出移动危机响应团队。',
    'hotline.sdaocl.call': '拨打 1-888-724-7240',
    'hotline.crisistext.name': 'Crisis Text Line（短信热线）',
    'hotline.crisistext.desc':
        '如果打字比打电话更方便，可随时发短信联系受过训练的危机辅导员，免费且保密。',
    'hotline.crisistext.sms': '发送 HOME 至 741741',
    'hotline.trevor.name': 'The Trevor Project',
    'hotline.trevor.desc':
        '面向 LGBTQ+ 青少年的 24 小时免费保密危机干预与自杀预防支持，可电话或短信联系。',
    'hotline.trevor.call': '拨打 1-866-488-7386',
    'hotline.trevor.sms': '发送 START 至 678678',
    'hotline.sandyhook.name': 'Say Something 匿名报告',
    'hotline.sandyhook.desc':
        '由危机辅导员接听的匿名报告渠道，可报告威胁、武器或可能面临伤害风险的同学。',
    'hotline.sandyhook.call': '拨打 1-844-5-SAYNOW',
    'hotline.pusdtip.name': 'PUSD "See Something, Say Something" 举报热线',
    'hotline.pusdtip.desc':
        'Poway 联合学区由执法部门监控的 24 小时匿名举报热线，用于报告校园威胁与安全问题'
        '（号码亦印在学生证背面）。',
    'hotline.pusdtip.call': '拨打 1-844-PUSD-TIP',

    'settings.title': '设置',
    'settings.safety': '安全',
    'settings.getHelp': '立即求助',
    'settings.getHelpSub':
        'Westview 辅导员、24 小时危机热线及匿名安全举报，离线可用。',
    'settings.quickExit': '快速退出',
    'settings.quickExitSub':
        '长按“求助”按钮即可立即关闭当前页面并将应用切到后台。',
    'settings.hideRecents': '在最近任务中隐藏预览',
    'settings.hideRecentsSub':
        '切到后台时将 Android 最近任务列表中的应用缩略图设为空白。',
    'settings.language': '语言',
    'settings.languageSub': '应用于求助、设置和导航栏。',
    'settings.privacy': '隐私与数据',
    'settings.about': '关于本应用',

    'privacy.title': '你的隐私',
    'privacy.intro': '开启后，本应用仅向学校服务器发送两类匿名数据：',
    'privacy.bullet1':
        '• 匿名使用计数：打开了哪些标签页以及刷新是否成功，不含姓名或账号。',
    'privacy.bullet2':
        '• 崩溃报告：发送前会先移除你在设置中填写的课程名、老师和教室号。',
    'privacy.never':
        '本应用不使用第三方统计工具，也绝不收集姓名、学号、通讯录、位置或广告标识符。',
    'privacy.offUntil':
        '两项开关默认关闭，除非你主动开启，且可随时在“设置 > 隐私与数据”中修改。',
    'privacy.dontShare': '不分享',
    'privacy.share': '匿名分享',
    'settings.notifications': '通知',
    'settings.notificationsSub': '允许 Westview HS 发送通知',
    'settings.liveActivity': '实时活动',
    'settings.liveOn': '常驻通知，实时倒计时显示当前课时结束时间',
    'settings.liveOff': '开启通知后才能使用实时活动',
    'settings.privacyData': '隐私与数据',
    'settings.analytics': '匿名使用统计',
    'settings.analyticsSub': '统计页面打开次数和刷新结果，不会识别你的身份。',
    'settings.crash': '崩溃报告',
    'settings.crashSub': '应用崩溃时发送错误信息与堆栈以便修复问题，不会识别你的身份。',
    'settings.collectTitle': '本应用收集的数据',
    'settings.collectBody':
        '上方两个开关默认关闭。开启后，应用会先剔除你在“我的课程”中填写的内容，再将匿名使用计数和崩溃报告发送至学校服务器；应用绝不收集姓名、学号、通讯录、位置或广告 ID。',
    'settings.savedContent': '已保存的内容',
    'settings.clear': '清除已保存内容',
    'settings.clearSub':
        '清除供离线查看的日历、午餐菜单和营养数据缓存，下次打开时会重新下载。',
    'settings.cleared': '已清除保存的内容',
    'settings.classDetails': '课程信息',
    'settings.showTeacher': '显示老师',
    'settings.showTeacherSub': '在课表、通知和小组件中显示老师姓名',
    'settings.showRoom': '显示教室号',
    'settings.showRoomSub': '在课表、通知和小组件中显示教室号',
    'settings.myClasses': '我的课程',
    'settings.resetClasses': '重置所有课程名称',
    'settings.resetTitle': '重置课程名称？',
    'settings.resetBody': '这会清除你填写的所有自定义课程名称、老师和教室号。',
    'settings.reset': '重置',
    'settings.tapToAdd': '点按添加课程名称、老师或教室',
    'settings.editClass': '课程名称',
    'settings.leaveEmpty': '留空则保留默认节次名称',
    'settings.teacher': '老师',
    'settings.room': '教室号',
    'settings.clearField': '清除',
    'settings.cancel': '取消',
    'settings.save': '保存',
    'settings.notCrisis':
        '本应用不是危机干预服务，也没有人实时查看。如果你或他人面临危险，请拨打 911。遇到情绪危机时，请拨打或发送短信至 988。',
    'settings.verified':
        '由于课表、菜单和链接可能在学年中变动，时间敏感的信息请向学校办公室确认。辅导员联系方式最后于 2025 年 11 月对照 Westview 辅导网页核实。',
    'settings.langLabel': '语言',
    'settings.langSystem': '跟随系统',
    'schedule.monFri': '周一/周五',
    'schedule.tueThu': '周二/周四',
    'schedule.wed': '周三',
    'schedule.noActivePeriod': '当前没有课程',
    'schedule.now': '现在',
    'schedule.endsAt': '结束于',
    'schedule.special': '今天启用特殊课表',
    'schedule.mayNotBeAccurate':
        '无法连接特殊课表服务器，因此今天显示的课表可能不是最新内容。',
    'schedule.dismiss': '关闭',
    'schedule.checking': '正在检查课表更新',
    'schedule.settings': '设置',
    'schedule.help': '求助',
    'schedule.helpTooltip': '立即求助。长按此按钮可立即退出到后台。',
    'common.selected': '已选择',
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
    'web.stale': '刷新失败，当前仍显示之前已加载的页面。',
    'calendar.tabSchool': '学校日历',
    'calendar.tabAthletics': '体育赛事',
    'calendar.tabLunch': '学校午餐',
    'calendar.errorTitle': '无法加载日历活动',
    'calendar.errorBody': '无法连接日历服务器。请检查网络连接后重试。',
    'calendar.loading': '正在加载活动…',
    'calendar.emptyTitle': '暂无即将举行的活动',
    'calendar.emptyBody': '该日历目前没有安排活动，下拉即可刷新。',
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
    'help.iconTooltipQuickExit': '%s（长按可立即退出应用）',
    'lunch.errorTitle': '无法加载午餐菜单',
    'lunch.errorBody': '无法连接菜单服务器。请检查网络连接后重试。',
    'lunch.loading': '正在加载菜单…',
    'lunch.emptyTitle': '尚未发布午餐菜单',
    'lunch.emptyBody': '本月的午餐菜单尚未发布，下拉即可刷新。',
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
    'common.copyNumber': 'Kopyahin ang numerong ito',
    'sms.confirmTitle': 'Ipadala ang text na ito?',
    'sms.openApp': 'Buksan ang Messages',
    'sms.editNote':
        'Bubukas ang iyong messaging app na nakalagay na ang keyword na ito '
        'para masuri o madagdagan mo bago ipadala.',

    'disclaimer.short':
        'Hindi ito app ng Poway Unified. Ginawa ito nang hiwalay ng mga '
        'estudyante at hindi itinataguyod o sinusuportahan ng Poway Unified '
        'School District o ng Westview High School.',
    'disclaimer.title': 'Hindi bahagi ng Poway Unified ang app na ito',
    'disclaimer.plain':
        'Ang Westview HS (WVAA) ay isang hiwalay na app na binuo ng mga '
        'estudyante at hindi ng Poway Unified School District o ng Westview '
        'High School. Dahil hindi ito pinapatakbo o sinusuri ng paaralan, '
        'maaaring hindi na updated ang mga iskedyul, link, o contact dito, '
        'kaya kumpirmahin ang mahahalagang detalye sa opisina ng paaralan, sa '
        'iyong counselor, o sa website ng Westview.',
    'disclaimer.crisis':
        'Hindi serbisyo para sa krisis ang app na ito at walang nagbabantay '
        'dito. Kung ikaw o ang ibang tao ay nasa panganib, tumawag sa 911. Sa '
        'emosyonal na krisis, tumawag o mag-text sa 988.',
    'disclaimer.translationNote':
        'Isinama ang mga isinaling buod para mas madaling maunawaan ang '
        'paalalang ito, habang ang opisyal na tekstong Ingles at Espanyol ng '
        'distrito pa rin ang umiiral na bersyon.',

    'help.title': 'Tulong',
    'help.emergency.title': 'May agarang panganib ba?',
    'help.emergency.body':
        'Tumawag agad sa 911 kung ikaw o ang ibang tao ay nanganganib masaktan '
        'at nangangailangan ng agarang tulong.',
    'help.emergency.call': 'Tumawag sa 911',
    'help.emergency.note':
        'Kung hindi ka sigurado kung emergency ang sitwasyon, tumawag o '
        'mag-text sa 988 para matulungan ka ng counselor sa susunod na '
        'hakbang.',

    'help.counselor.title': 'Kausapin ang counselor sa Westview',
    'help.counselor.body':
        'Nasa Wolverine Center ang mga counselor ng Westview sa oras ng klase. '
        'Maaaring dumaan nang personal, humingi ng pass sa teacher, o '
        'mag-email nang direkta sa iyong counselor nang hindi kailangang '
        'ipaliwanag ang lahat sa unang mensahe.',
    'help.counselor.callOffice': 'Tumawag sa opisina',
    'help.counselor.website': 'Website ng counseling',
    'help.counselor.find': 'Hanapin ang iyong counselor',
    'help.counselor.byLast': 'Naka-assign ayon sa unang letra ng apelyido mo.',
    'help.counselor.career': 'Mga tanong sa kolehiyo at karera',
    'help.counselor.verified':
        'Maaaring magbago ang naka-assign na counselor sa loob ng school year, '
        'kaya tingnan ang website ng Westview o ang counseling office kung '
        'hindi tugma ang apelyido mo sa listahan sa ibaba. (Sinuri noong '
        'Nobyembre 2025.)',

    'help.crisis.title': 'Libreng 24/7 at kompidensyal na mga crisis line',
    'help.crisis.call': 'Tumawag',
    'help.crisis.text': 'Mag-text',
    'help.crisis.deaf':
        'Kung ikaw ay bingi, hirap sa pandinig, o hindi makapagsalita nang '
        'malakas, lahat ng serbisyo sa ibaba ay maaabot din sa text o online. '
        'Direktang tumatanggap ng text ang 988 at Crisis Text Line, habang '
        'tumatanggap naman ng 711 relay call ang linya ng San Diego County.',

    'help.report.title': 'Mag-ulat ng alalahanin sa kaligtasan',
    'help.report.body':
        'Kung nag-aalala ka tungkol sa isang kaklase, banta, armas, o isang '
        'post online, magsabi sa mapagkakatiwalaang nakatatanda gaya ng '
        'teacher, counselor, coach, o magulang. Maaari ding mag-ulat nang '
        'anonymous sa mga linyang ito:',
    'help.report.note':
        'Hindi mo kailangang magkaroon ng buong ebidensya bago mag-ulat, dahil '
        'sinusuri ng sinanay na staff ang bawat tip para malaman kung anong '
        'tulong ang kailangan.',

    'help.about.title': 'Tungkol sa app na ito',

    'hotline.988.name': '988 Suicide & Crisis Lifeline',
    'hotline.988.desc':
        'Libre at kompidensyal na 24/7 na suporta sa tawag o text para sa '
        'sinumang nakararanas ng matinding lungkot o krisis.',
    'hotline.988.call': 'Tumawag sa 988',
    'hotline.988.sms': 'I-text ang 988',
    'hotline.sdaocl.name': 'San Diego Access & Crisis Line',
    'hotline.sdaocl.desc':
        '24/7 na linya ng San Diego County para sa mental health o '
        'substance-use crisis para sa iyo o sa kakilala mo, na may libreng '
        'interpreter sa mahigit 200 wika at mobile crisis team kung kailangan.',
    'hotline.sdaocl.call': 'Tumawag sa 1-888-724-7240',
    'hotline.crisistext.name': 'Crisis Text Line',
    'hotline.crisistext.desc':
        'Nagkokonekta sa iyo sa sinanay na crisis counselor sa pamamagitan ng '
        'text anumang oras kung mas madali ang mag-type kaysa tumawag. Libre '
        'at kompidensyal.',
    'hotline.crisistext.sms': 'I-text ang HOME sa 741741',
    'hotline.trevor.name': 'The Trevor Project',
    'hotline.trevor.desc':
        'Libre at kompidensyal na 24/7 na suporta sa krisis at pag-iwas sa '
        'pagpapatiwakal para sa mga kabataang LGBTQ+ sa tawag o text.',
    'hotline.trevor.call': 'Tumawag sa 1-866-488-7386',
    'hotline.trevor.sms': 'I-text ang START sa 678678',
    'hotline.sandyhook.name': 'Say Something Anonymous Reporting',
    'hotline.sandyhook.desc':
        'Anonymous na linya na sinasagot ng mga crisis counselor para sa mga '
        'banta, armas, o pag-aalala na baka mapahamak ang isang kaklase.',
    'hotline.sandyhook.call': 'Tumawag sa 1-844-5-SAYNOW',
    'hotline.pusdtip.name': 'PUSD "See Something, Say Something" Tip Line',
    'hotline.pusdtip.desc':
        '24-oras na anonymous tip line ng Poway Unified na binabantayan ng law '
        'enforcement para sa mga banta at kaligtasan sa paaralan (nakaprinta '
        'rin sa likod ng student ID).',
    'hotline.pusdtip.call': 'Tumawag sa 1-844-PUSD-TIP',

    'settings.title': 'Mga Setting',
    'settings.safety': 'Kaligtasan',
    'settings.getHelp': 'Kumuha ng tulong ngayon',
    'settings.getHelpSub':
        'Mga counselor sa Westview, 24/7 crisis line, at anonymous na pag-uulat '
        'sa kaligtasan. Gumagana kahit offline.',
    'settings.quickExit': 'Mabilisang paglabas',
    'settings.quickExitSub':
        'Pindutin nang matagal ang Help button para isara agad ang screen na '
        'ito at ilipat ang app sa background.',
    'settings.hideRecents': 'Itago ang preview sa app switcher',
    'settings.hideRecentsSub':
        'Ginagawang blangko ang preview ng app sa listahan ng recent apps sa '
        'Android habang nasa background.',
    'settings.language': 'Wika',
    'settings.languageSub': 'Naaangkop sa Tulong, Mga Setting, at navigation.',
    'settings.privacy': 'Privacy at data',
    'settings.about': 'Tungkol sa app na ito',

    'privacy.title': 'Ang iyong privacy',
    'privacy.intro':
        'Kapag binuksan mo ito, dalawang uri lang ng anonymous na data ang '
        'ipinapadala ng app sa server ng paaralan:',
    'privacy.bullet1':
        '• Anonymous na bilang ng paggamit: kung aling tab ang binubuksan at '
        'kung gumana ang refresh, nang walang pangalan o account.',
    'privacy.bullet2':
        '• Mga crash report: detalye ng error matapos alisin ang anumang '
        'pangalan ng klase, teacher, o room na inilagay sa Mga Setting.',
    'privacy.never':
        'Hindi gumagamit ang app ng third-party analytics at hindi nito '
        'kinokolekta ang pangalan, student ID, contacts, lokasyon, o '
        'advertising ID.',
    'privacy.offUntil':
        'Naka-off ang parehong opsyon maliban kung buksan mo, at maaari mo '
        'itong baguhin anumang oras sa Mga Setting > Privacy at data.',
    'privacy.dontShare': 'Huwag ibahagi',
    'privacy.share': 'Ibahagi nang anonymous',
    'settings.notifications': 'Mga abiso',
    'settings.notificationsSub':
        'Payagan ang Westview HS na magpadala ng abiso',
    'settings.liveActivity': 'Live na aktibidad',
    'settings.liveOn':
        'Tuloy-tuloy na abiso na may countdown hanggang matapos ang '
        'kasalukuyang period',
    'settings.liveOff': 'Buksan ang abiso para magamit ang live na aktibidad',
    'settings.privacyData': 'Privacy at data',
    'settings.analytics': 'Anonymous na estadistika ng paggamit',
    'settings.analyticsSub':
        'Binibilang kung aling screen ang binubuksan at kung gumagana ang '
        'refresh, nang hindi ka nakikilala.',
    'settings.crash': 'Mga crash report',
    'settings.crashSub':
        'Nagpapadala ng detalye ng error at stack trace kapag nag-crash ang '
        'app para maayos ang bug, nang hindi ka nakikilala.',
    'settings.collectTitle': 'Ano ang kinokolekta ng app na ito',
    'settings.collectBody':
        'Naka-off ang dalawang switch hangga\'t hindi mo binubuksan. Kapag '
        'naka-on, nagpapadala ang app ng anonymous na bilang ng paggamit at '
        'crash report sa server ng paaralan matapos alisin ang anumang '
        'inilagay sa Aking mga klase, at hindi ito kumokolekta ng pangalan, '
        'student ID, contacts, lokasyon, o advertising ID.',
    'settings.savedContent': 'Naka-save na content',
    'settings.clear': 'Burahin ang naka-save na content',
    'settings.clearSub':
        'Tinatanggal ang naka-cache na kalendaryo, menu ng tanghalian, at '
        'nutrition data para ma-download nang bago sa susunod na bukas.',
    'settings.cleared': 'Nabura ang naka-save na content',
    'settings.classDetails': 'Detalye ng klase',
    'settings.showTeacher': 'Ipakita ang teacher',
    'settings.showTeacherSub':
        'Ipakita ang pangalan ng teacher sa iskedyul, abiso, at widget',
    'settings.showRoom': 'Ipakita ang room number',
    'settings.showRoomSub':
        'Ipakita ang room number sa iskedyul, abiso, at widget',
    'settings.myClasses': 'Aking mga klase',
    'settings.resetClasses': 'I-reset ang lahat ng pangalan ng klase',
    'settings.resetTitle': 'I-reset ang mga pangalan?',
    'settings.resetBody':
        'Buburahin nito ang lahat ng custom na pangalan ng klase, teacher, at '
        'room number na inilagay mo.',
    'settings.reset': 'I-reset',
    'settings.tapToAdd': 'I-tap para magdagdag ng klase, teacher, o room',
    'settings.editClass': 'Pangalan ng klase',
    'settings.leaveEmpty':
        'Iwanang blangko para panatilihin ang default na pangalan ng period',
    'settings.teacher': 'Teacher',
    'settings.room': 'Room number',
    'settings.clearField': 'Burahin',
    'settings.cancel': 'Kanselahin',
    'settings.save': 'I-save',
    'settings.notCrisis':
        'Hindi serbisyo para sa krisis ang app na ito at walang nagbabantay '
        'dito. Kung ikaw o ang ibang tao ay nasa panganib, tumawag sa 911. Sa '
        'emosyonal na krisis, tumawag o mag-text sa 988.',
    'settings.verified':
        'Dahil maaaring magbago ang mga iskedyul, menu, at link sa loob ng '
        'school year, kumpirmahin sa opisina ng paaralan ang mahahalagang '
        'detalye. Huling sinuri ang mga contact sa counseling noong Nobyembre '
        '2025 batay sa counseling webpage ng Westview.',
    'settings.langLabel': 'Wika',
    'settings.langSystem': 'Default ng system',
    'schedule.monFri': 'Lun/Biy',
    'schedule.tueThu': 'Mar/Huw',
    'schedule.wed': 'Miy',
    'schedule.noActivePeriod': 'Walang aktibong period',
    'schedule.now': 'Ngayon',
    'schedule.endsAt': 'matatapos nang',
    'schedule.special': 'May espesyal na iskedyul ngayong araw',
    'schedule.mayNotBeAccurate':
        'Hindi maabot ang server ng espesyal na iskedyul, kaya maaaring hindi '
        'updated ang iskedyul ngayong araw.',
    'schedule.dismiss': 'Isara',
    'schedule.checking': 'Sinusuri ang update sa iskedyul',
    'schedule.settings': 'Mga Setting',
    'schedule.help': 'Tulong',
    'schedule.helpTooltip':
        'Kumuha ng tulong ngayon. Pindutin nang matagal ang button na ito para '
        'isara agad ang app.',
    'common.selected': 'Napili',
    'common.refresh': 'I-refresh',
    'common.dismiss': 'Isara',
    'common.retry': 'Subukan muli',
    'newsletter.weekly': 'Lingguhang Newsletter',
    'newsletter.counseling': 'Newsletter ng Counseling',
    'newsletter.den': 'Mga Anunsyo ng Den',
    'publications.nexus': 'Westview Nexus',
    'publications.newscast': 'Westview Newscast',
    'web.errorTitle': 'Hindi mabuksan ang pahinang ito',
    'web.errorBody':
        'Hindi na-load ang pahina. Suriin ang koneksyon at subukan muli.',
    'web.loading': 'Naglo-load ng pahina…',
    'web.stale':
        'Hindi gumana ang refresh, kaya ipinapakita pa rin ang huling na-load '
        'na pahina.',
    'calendar.tabSchool': 'Kalendaryo ng Paaralan',
    'calendar.tabAthletics': 'Atletika',
    'calendar.tabLunch': 'Tanghalian sa Paaralan',
    'calendar.errorTitle': 'Hindi ma-load ang mga event',
    'calendar.errorBody':
        'Hindi maabot ang calendar server. Suriin ang koneksyon at subukan '
        'muli.',
    'calendar.loading': 'Naglo-load ng mga event…',
    'calendar.emptyTitle': 'Walang darating na event',
    'calendar.emptyBody':
        'Walang naka-iskedyul sa kalendaryong ito ngayon. Hilahin pababa para '
        'i-refresh.',
    'calendar.savedCopy': 'Naka-save na kopya mula',
    'calendar.untitled': 'Event na walang pamagat',
    'calendar.description': 'Paglalarawan',
    'calendar.noDescription': 'Walang ibinigay na paglalarawan.',
    'calendar.allDay': 'Buong araw',
    'calendar.today': 'Ngayon',
    'calendar.yesterday': 'Kahapon',
    'calendar.tomorrow': 'Bukas',
    'calendar.weekdays':
        'Lunes,Martes,Miyerkules,Huwebes,Biyernes,Sabado,Linggo',
    'calendar.am': 'AM',
    'calendar.pm': 'PM',
    'schedule.refresh': 'Nire-refresh ang iskedyul…',
    'settings.langPickTitle': 'Wika ng app',
    'web.retry': 'Subukan muli',
    'common.loading': 'Naglo-load…',
    'common.errorTitle': 'Hindi ma-load ngayon',
    'help.iconTooltip': 'Humingi ng tulong ngayon',
    'help.iconTooltipQuickExit': '%s (pindutin nang matagal para lumabas agad)',
    'lunch.errorTitle': 'Hindi ma-load ang menu',
    'lunch.errorBody':
        'Hindi maabot ang menu server. Suriin ang koneksyon at subukan muli.',
    'lunch.loading': 'Naglo-load ng menu…',
    'lunch.emptyTitle': 'Walang naka-publish na menu',
    'lunch.emptyBody':
        'Wala pang naka-post na menu ng tanghalian ngayong buwan. Hilahin '
        'pababa para i-refresh.',
    'lunch.savedCopy': 'Naka-save na menu mula',
    'lunch.noSchool': 'Walang pasok',
    'lunch.entrees': 'Pangunahing Putahe',
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
    'help.counselor.emailSubject':
        'Tanong ng estudyante para sa aking counselor',
    'help.counselor.careerTitle': 'Gabay sa kolehiyo at karera',
    'help.counselor.careerRole': 'College & Career Guidance Technician',
    'settings.roomShort': 'Rm',
  },
};
