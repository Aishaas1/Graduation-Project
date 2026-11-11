// Retain compatibility with Flutter versions before the Material package split.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('DEMO', defaultValue: true);
  Store store = DemoStore();
  String? startupError;
  if (!demo) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
          storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
          authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        ),
      );
      final firebase = FirebaseStore();
      await firebase.loadUser();
      store = firebase;
    } catch (_) {
      startupError =
          'تعذر الاتصال بـ Firebase. تحقق من إعدادات المشروع واتصال الشبكة ثم أعد التشغيل.';
    }
  }
  runApp(ComplaintsApp(store: store, startupError: startupError));
}

class ComplaintsApp extends StatefulWidget {
  final Store store;
  final String? startupError;
  const ComplaintsApp({super.key, required this.store, this.startupError});
  @override
  State<ComplaintsApp> createState() => _ComplaintsAppState();
}

class _ComplaintsAppState extends State<ComplaintsApp> {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'صوتك | شكاوى ذمار',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    // ignore: deprecated_member_use
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansArabic',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff12665b)),
      scaffoldBackgroundColor: const Color(0xfff4f7f6),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
      ),
    ),
    home: widget.startupError != null
        ? Scaffold(body: Center(child: Text(widget.startupError!)))
        : widget.store.user == null
        ? AuthPage(store: widget.store, onDone: () => setState(() {}))
        : HomePage(store: widget.store, onLogout: () => setState(() {})),
  );
}

void notify(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
String friendly(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'email-already-in-use' => 'البريد مستخدم بالفعل',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'البريد أو كلمة المرور غير صحيحة',
      'too-many-requests' => 'محاولات كثيرة؛ حاول لاحقًا',
      'network-request-failed' => 'تحقق من اتصال الإنترنت',
      _ => 'تعذر إكمال العملية. تحقق من البيانات وإعدادات الخدمة.',
    };
  }
  return e.toString().startsWith('Exception:')
      ? e.toString().replaceFirst('Exception: ', '')
      : 'تعذر إكمال العملية. تحقق من الاتصال والصلاحيات ثم حاول مجددًا.';
}

class AuthPage extends StatefulWidget {
  final Store store;
  final VoidCallback onDone;
  const AuthPage({super.key, required this.store, required this.onDone});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool signup = false, busy = false, hidden = true;
  @override
  void dispose() {
    for (final c in [name, phone, email, password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    try {
      if (signup) {
        await widget.store.register(
          name.text.trim(),
          phone.text.trim(),
          email.text.trim(),
          password.text,
        );
      } else {
        await widget.store.login(email.text.trim(), password.text);
      }
      widget.onDone();
    } catch (e) {
      if (mounted) {
        notify(context, friendly(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.record_voice_over_rounded,
                  size: 62,
                  color: Color(0xff12665b),
                ),
                const SizedBox(height: 12),
                const Text(
                  'صوتك يصل',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'بوابة شكاوى محافظة ذمار',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Text(
                  signup ? 'إنشاء حساب مواطن' : 'مرحبًا بعودتك',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                if (signup) ...[
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                    ),
                    validator: requiredText,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                    validator: (v) =>
                        RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v ?? '')
                        ? null
                        : 'أدخل رقم هاتف صحيحًا',
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                  ),
                  validator: emailError,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: hidden,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: passwordError,
                  onFieldSubmitted: (_) => busy ? null : submit(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      busy
                          ? 'جارٍ المتابعة…'
                          : signup
                          ? 'إنشاء الحساب'
                          : 'تسجيل الدخول',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => signup = !signup),
                  child: Text(
                    signup
                        ? 'لديك حساب؟ تسجيل الدخول'
                        : 'مستخدم جديد؟ إنشاء حساب',
                  ),
                ),
                if (!signup)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (emailError(email.text) != null) {
                              notify(context, 'أدخل بريدك الإلكتروني أولًا');
                              return;
                            }
                            try {
                              await widget.store.reset(email.text.trim());
                              if (mounted) {
                                notify(
                                  this.context,
                                  'إذا كان الحساب مسجلًا فستصلك تعليمات الاستعادة',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                notify(this.context, friendly(e));
                              }
                            }
                          },
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                if (widget.store.demo)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'وضع تجريبي • البيانات مؤقتة وتُفقد عند إغلاق التطبيق',
                          ),
                          const SizedBox(height: 8),
                          const SelectableText(
                            'citizen@example.com\nadmin@example.com\nDemo12345!',
                            textDirection: TextDirection.ltr,
                          ),
                          TextButton(
                            onPressed: () {
                              email.text = 'citizen@example.com';
                              password.text = 'Demo12345!';
                            },
                            child: const Text('تعبئة حساب المواطن'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  final Store store;
  final VoidCallback onLogout;
  const HomePage({super.key, required this.store, required this.onLogout});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Stream<List<Complaint>> stream;
  String query = '', filter = 'الكل';
  @override
  void initState() {
    super.initState();
    stream = widget.store.complaints();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.store.user!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('صوتك | ذمار'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await widget.store.logout();
              widget.onLogout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: u.admin
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewComplaint(store: widget.store),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('تقديم شكوى'),
            ),
      body: StreamBuilder<List<Complaint>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('تعذر تحميل الشكاوى. تحقق من الاتصال والصلاحيات.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final items = all
              .where(
                (c) =>
                    (filter == 'الكل' || c.status == filter) &&
                    '${c.id} ${c.title} ${c.ownerName}'.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  if (widget.store.demo)
                    const Text(
                      'نسخة تجريبية • بيانات مؤقتة',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'أهلًا، ${u.name}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    u.admin
                        ? 'لوحة الإدارة — متابعة الشكاوى والتواصل مع المواطنين'
                        : 'من هنا تبدأ الخطوة الأولى نحو خدمة أفضل.',
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      metric(
                        'إجمالي الشكاوى',
                        all.length,
                        Icons.folder_outlined,
                      ),
                      metric(
                        'قيد المتابعة',
                        all
                            .where(
                              (c) => !['تم الحل', 'مرفوضة'].contains(c.status),
                            )
                            .length,
                        Icons.timelapse,
                      ),
                      metric(
                        'تم الحل',
                        all.where((c) => c.status == 'تم الحل').length,
                        Icons.task_alt,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    u.admin ? 'شكاوى المواطنين' : 'شكواي',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'ابحث بعنوان الشكوى أو رقمها',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: ['الكل', ...statuses]
                        .map(
                          (s) => ChoiceChip(
                            label: Text(s),
                            selected: filter == s,
                            onSelected: (_) => setState(() => filter = s),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 54),
                          Text(
                            'لا توجد شكاوى مطابقة. يمكنك تغيير البحث أو تقديم شكوى جديدة.',
                          ),
                        ],
                      ),
                    ),
                  ...items.map(
                    (c) => Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(
                          child: Icon(Icons.description_outlined),
                        ),
                        title: Text(
                          c.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${c.category} • ${c.district}\n${c.id}\n${u.admin ? c.ownerName : date(c.created)}',
                        ),
                        trailing: Chip(label: Text(c.status)),
                        isThreeLine: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComplaintPage(
                              store: widget.store,
                              complaint: c,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget metric(String title, int count, IconData icon) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xff12665b)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(title),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String date(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

class NewComplaint extends StatefulWidget {
  final Store store;
  const NewComplaint({super.key, required this.store});
  @override
  State<NewComplaint> createState() => _NewComplaintState();
}

class _NewComplaintState extends State<NewComplaint> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in [
      'title',
      'description',
      'district',
      'accused',
      'employer',
      'accusedPhone',
    ])
      key: TextEditingController(),
  };
  String category = categories.first;
  bool consent = false, busy = false;
  List<PlatformFile> files = [];
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    if (!consent) {
      notify(context, 'يرجى تأكيد صحة البيانات');
      return;
    }
    setState(() => busy = true);
    try {
      final id = await widget.store.submit({
        ...fields.map((k, v) => MapEntry(k, v.text.trim())),
        'category': category,
      }, files);
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تم استلام شكواك'),
            content: SelectableText('احتفظ برقم المتابعة:\n$id'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        notify(context, friendly(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تقديم شكوى جديدة')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'تفاصيل واضحة تساعدنا على خدمتك',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text('بيانات الشكوى متاحة لك ولإدارة الشكاوى فقط.'),
              const SizedBox(height: 20),
              input('title', 'عنوان الشكوى', max: 150),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'نوع الشكوى'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 14),
              input('district', 'المديرية / المنطقة'),
              input('description', 'تفاصيل الشكوى', lines: 5, max: 5000),
              const Text(
                'بيانات المشكو عليه (اختيارية)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              input('accused', 'الاسم أو الصفة', required: false),
              input('employer', 'جهة العمل', required: false),
              input('accusedPhone', 'رقم الهاتف', required: false),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          final picked = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                          );
                          if (picked != null) {
                            if (picked.files.length > 3 ||
                                picked.files.any(
                                  (f) =>
                                      f.size > 5 * 1024 * 1024 ||
                                      f.bytes == null,
                                )) {
                              if (context.mounted) {
                                notify(
                                  context,
                                  'الحد الأقصى 3 ملفات، كل ملف حتى 5 ميجابايت',
                                );
                              }
                              return;
                            }
                            setState(() => files = picked.files);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            notify(context, friendly(e));
                          }
                        }
                      },
                icon: const Icon(Icons.attach_file),
                label: const Text('إرفاق مستندات (PDF أو صور)'),
              ),
              ...files.map(
                (f) => ListTile(
                  title: Text(f.name),
                  trailing: IconButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => files.remove(f)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              CheckboxListTile(
                value: consent,
                onChanged: busy ? null : (v) => setState(() => consent = v!),
                title: const Text(
                  'أقر بصحة البيانات وأوافق على مشاركتها مع الإدارة لمعالجة الشكوى.',
                ),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(busy ? 'جارٍ إرسال الشكوى…' : 'إرسال الشكوى'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget input(
    String key,
    String label, {
    bool required = true,
    int lines = 1,
    int max = 200,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: fields[key],
      enabled: !busy,
      maxLines: lines,
      maxLength: max,
      decoration: InputDecoration(labelText: label),
      validator: required ? requiredText : null,
    ),
  );
}

class ComplaintPage extends StatefulWidget {
  final Store store;
  final Complaint complaint;
  const ComplaintPage({
    super.key,
    required this.store,
    required this.complaint,
  });
  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final message = TextEditingController();
  late Stream<List<Entry>> entries;
  late Stream<List<Complaint>> complaints;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    entries = widget.store.entries(widget.complaint.id);
    complaints = widget.store.complaints();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() operation) async {
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        notify(context, friendly(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تفاصيل الشكوى')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            StreamBuilder<List<Complaint>>(
              stream: complaints,
              builder: (context, s) {
                final c =
                    (s.data ?? [widget.complaint])
                        .where((c) => c.id == widget.complaint.id)
                        .firstOrNull ??
                    widget.complaint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      c.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SelectableText(c.id),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(label: Text(c.status)),
                        Chip(label: Text(c.category)),
                        Chip(label: Text(date(c.created))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'المواطن: ${c.ownerName}\nالمنطقة: ${c.district}\nالمشكو عليه: ${c.accused.isEmpty ? 'غير محدد' : c.accused}\nجهة العمل: ${c.employer}\nهاتف المشكو عليه: ${c.accusedPhone}',
                    ),
                    const Divider(height: 32),
                    Text(
                      c.description,
                      style: const TextStyle(fontSize: 17, height: 1.8),
                    ),
                    ...c.attachments.map(
                      (a) => ListTile(
                        leading: const Icon(Icons.attachment),
                        title: Text(a['name']!),
                        subtitle: widget.store.demo
                            ? const Text(
                                'معاينة تجريبية؛ لم يُرفع الملف إلى خادم',
                              )
                            : null,
                        onTap: widget.store.demo
                            ? null
                            : () => action(() async {
                                final url = await FirebaseStorage.instance
                                    .ref(a['path'])
                                    .getDownloadURL();
                                if (!await launchUrl(
                                  Uri.parse(url),
                                  mode: LaunchMode.externalApplication,
                                )) {
                                  throw StateError('تعذر فتح الملف');
                                }
                              }),
                      ),
                    ),
                    if (widget.store.user!.admin) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey(c.status),
                        initialValue: c.status,
                        decoration: const InputDecoration(
                          labelText: 'تحديث حالة الشكوى',
                        ),
                        items: statuses
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) =>
                                  action(() => widget.store.setStatus(c, v!)),
                      ),
                    ],
                  ],
                );
              },
            ),
            const Divider(height: 40),
            const Text(
              'المتابعة والمراسلات',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Entry>>(
              stream: entries,
              builder: (context, s) {
                if (s.hasError) {
                  return const Text('تعذر تحميل الرسائل');
                }
                if (!s.hasData) {
                  return const LinearProgressIndicator();
                }
                if (s.data!.isEmpty) {
                  return const Text(
                    'لا توجد رسائل بعد. ابدأ التواصل مع الإدارة هنا.',
                  );
                }
                return Column(
                  children: s.data!
                      .map(
                        (e) => Align(
                          alignment: e.senderId == widget.store.user!.id
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Card(
                            color: e.event
                                ? const Color(0xffe5ece9)
                                : e.senderId == widget.store.user!.id
                                ? const Color(0xffd8eee5)
                                : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.author} • ${date(e.time)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(e.text),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: message,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'اكتب رسالتك'),
            ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      final text = message.text.trim();
                      if (text.isEmpty) {
                        return;
                      }
                      await widget.store.send(widget.complaint.id, text);
                      message.clear();
                    }),
              icon: const Icon(Icons.send),
              label: Text(busy ? 'جارٍ الحفظ…' : 'إرسال الرسالة'),
            ),
          ],
        ),
      ),
    ),
  );
}
