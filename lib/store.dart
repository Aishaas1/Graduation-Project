import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'models.dart';

abstract class Store {
  Account? user;
  bool get demo;
  Future<void> login(String email, String password);
  Future<void> register(
    String name,
    String phone,
    String email,
    String password,
  );
  Future<void> logout();
  Future<void> reset(String email);
  Stream<List<Complaint>> complaints();
  Stream<List<Entry>> entries(String id);
  Future<String> submit(Map<String, String> fields, List<PlatformFile> files);
  Future<void> send(String id, String text);
  Future<void> setStatus(Complaint complaint, String status);
}

class DemoStore extends Store {
  @override
  bool get demo => true;
  final _changes = StreamController<void>.broadcast();
  final List<Complaint> _items = [];
  final Map<String, List<Entry>> _entries = {};
  @override
  Future<void> login(String email, String password) async {
    if (password != 'Demo12345!' ||
        !['citizen@example.com', 'admin@example.com'].contains(email)) {
      throw Exception('استخدم بيانات الحساب التجريبي الموضحة أدناه');
    }
    user = Account(
      email.startsWith('admin') ? 'admin' : 'citizen',
      email.startsWith('admin') ? 'مدير الشكاوى' : 'أحمد محمد',
      email,
      '777123456',
      admin: email.startsWith('admin'),
    );
    if (_items.isEmpty) {
      _items.add(
        Complaint(
          id: 'DM-2026-1001',
          ownerId: 'citizen',
          ownerName: 'أحمد محمد',
          title: 'انقطاع المياه عن الحي',
          category: 'مياه وصرف صحي',
          description:
              'نرجو مراجعة انقطاع المياه المستمر عن الحي منذ ثلاثة أيام.',
          district: 'مدينة ذمار',
          created: DateTime.now().subtract(const Duration(days: 2)),
          status: 'قيد المعالجة',
        ),
      );
      _entries[_items.first.id] = [
        Entry(
          'الإدارة',
          'تم تحويل الشكوى إلى مكتب المياه للمتابعة.',
          'admin',
          DateTime.now(),
        ),
      ];
    }
  }

  @override
  Future<void> register(
    String name,
    String phone,
    String email,
    String password,
  ) async {
    user = Account(
      'demo-${DateTime.now().microsecondsSinceEpoch}',
      name,
      email,
      phone,
    );
  }

  @override
  Future<void> logout() async {
    user = null;
  }

  @override
  Future<void> reset(String email) async {
    throw Exception('استعادة كلمة المرور متاحة عند ربط Firebase فقط');
  }

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<List<Complaint>> complaints() => _watch(
    () =>
        _items.where((c) => user!.admin || c.ownerId == user!.id).toList()
          ..sort((a, b) => b.created.compareTo(a.created)),
  );
  @override
  Stream<List<Entry>> entries(String id) =>
      _watch(() => List.of(_entries[id] ?? []));
  @override
  Future<String> submit(Map<String, String> f, List<PlatformFile> files) async {
    final id = 'DM-${DateTime.now().microsecondsSinceEpoch}';
    _items.add(
      Complaint.fromMap(id, {
        ...f,
        'ownerId': user!.id,
        'ownerName': user!.name,
        'created': DateTime.now().toIso8601String(),
        'status': 'جديدة',
        'attachments': files.map((f) => {'name': f.name, 'url': ''}).toList(),
      }),
    );
    _entries[id] = [
      Entry(
        'النظام',
        'تم استلام الشكوى',
        user!.id,
        DateTime.now(),
        event: true,
      ),
    ];
    _changes.add(null);
    return id;
  }

  @override
  Future<void> send(String id, String text) async {
    (_entries[id] ??= []).add(
      Entry(user!.name, text, user!.id, DateTime.now()),
    );
    _changes.add(null);
  }

  @override
  Future<void> setStatus(Complaint c, String status) async {
    if (!user!.admin) {
      throw StateError('غير مصرح');
    }
    c.status = status;
    (_entries[c.id] ??= []).add(
      Entry(
        user!.name,
        'تغيرت الحالة إلى $status',
        user!.id,
        DateTime.now(),
        event: true,
      ),
    );
    _changes.add(null);
  }
}

class FirebaseStore extends Store {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  @override
  bool get demo => false;
  Future<void> loadUser() async {
    final u = auth.currentUser;
    if (u == null) {
      user = null;
      return;
    }
    final p = (await db.collection('users').doc(u.uid).get()).data();
    if (p == null) {
      throw StateError('ملف الحساب غير مكتمل؛ تواصل مع الإدارة');
    }
    final token = await u.getIdTokenResult(true);
    user = Account(
      u.uid,
      p['name'],
      u.email!,
      p['phone'],
      admin: token.claims?['admin'] == true,
    );
  }

  @override
  Future<void> login(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email, password: password);
    await loadUser();
  }

  @override
  Future<void> register(
    String name,
    String phone,
    String email,
    String password,
  ) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      await db.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'phone': phone,
        'email': email,
      });
    } catch (_) {
      await credential.user!.delete();
      rethrow;
    }
    await loadUser();
  }

  @override
  Future<void> logout() async {
    await auth.signOut();
    user = null;
  }

  @override
  Future<void> reset(String email) => auth.sendPasswordResetEmail(email: email);
  @override
  Stream<List<Complaint>> complaints() {
    Query<Map<String, dynamic>> query = db.collection('complaints');
    if (!user!.admin) {
      query = query.where('ownerId', isEqualTo: user!.id);
    }
    return query.snapshots().map(
      (s) =>
          s.docs.map((d) => Complaint.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.created.compareTo(a.created)),
    );
  }

  @override
  Stream<List<Entry>> entries(String id) => db
      .collection('complaints')
      .doc(id)
      .collection('messages')
      .orderBy('time')
      .snapshots()
      .map((s) => s.docs.map((d) => Entry.fromMap(d.data())).toList());
  @override
  Future<String> submit(
    Map<String, String> fields,
    List<PlatformFile> files,
  ) async {
    final doc = db.collection('complaints').doc();
    final c = Complaint.fromMap(doc.id, {
      ...fields,
      'ownerId': user!.id,
      'ownerName': user!.name,
      'created': DateTime.now().toIso8601String(),
      'status': 'جديدة',
    });
    await doc.set(c.toMap());
    final uploaded = <Map<String, String>>[];
    try {
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final ref = FirebaseStorage.instance.ref(
          'complaints/${user!.id}/${doc.id}/$i-${f.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}',
        );
        final ext = f.extension?.toLowerCase();
        await ref.putData(
          f.bytes!,
          SettableMetadata(
            contentType: ext == 'pdf'
                ? 'application/pdf'
                : ext == 'png'
                ? 'image/png'
                : 'image/jpeg',
          ),
        );
        uploaded.add({'name': f.name, 'path': ref.fullPath, 'url': ''});
      }
      await doc.update({'attachments': uploaded});
    } catch (_) {
      for (final a in uploaded) {
        await FirebaseStorage.instance.ref(a['path']).delete();
      }
      await doc.delete();
      rethrow;
    }
    return doc.id;
  }

  @override
  Future<void> send(String id, String text) => db
      .collection('complaints')
      .doc(id)
      .collection('messages')
      .add(Entry(user!.name, text, user!.id, DateTime.now()).toMap())
      .then((_) {});
  @override
  Future<void> setStatus(Complaint c, String status) async {
    if (!user!.admin || !statuses.contains(status)) {
      throw StateError('غير مصرح');
    }
    final doc = db.collection('complaints').doc(c.id);
    final batch = db.batch();
    batch.update(doc, {'status': status});
    batch.set(
      doc.collection('messages').doc(),
      Entry(
        user!.name,
        'تغيرت الحالة إلى $status',
        user!.id,
        DateTime.now(),
        event: true,
      ).toMap(),
    );
    await batch.commit();
  }
}
