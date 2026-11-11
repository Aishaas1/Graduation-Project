import 'package:flutter_test/flutter_test.dart';
import 'package:dhamar_complaints/models.dart';
import 'package:dhamar_complaints/store.dart';

void main() {
  test(
    'citizen submits, admin replies, status is visible to citizen',
    () async {
      final store = DemoStore();
      await store.login('citizen@example.com', 'Demo12345!');
      final id = await store.submit({
        'title': 'مشكلة الطريق',
        'description': 'تحتاج الطريق إلى صيانة',
        'category': 'طرق',
        'district': 'ذمار',
        'accused': '',
        'employer': '',
        'accusedPhone': '',
      }, []);
      expect((await store.complaints().first).any((c) => c.id == id), isTrue);
      await store.send(id, 'يرجى المتابعة');
      await store.logout();
      await store.login('admin@example.com', 'Demo12345!');
      final c = (await store.complaints().first).firstWhere((c) => c.id == id);
      await store.setStatus(c, 'تم الحل');
      await store.send(id, 'تمت الصيانة');
      await store.logout();
      await store.login('citizen@example.com', 'Demo12345!');
      expect(
        (await store.complaints().first).firstWhere((c) => c.id == id).status,
        'تم الحل',
      );
      expect((await store.entries(id).first).last.text, 'تمت الصيانة');
    },
  );
  test(
    'another citizen cannot see complaints and cannot change status',
    () async {
      final store = DemoStore();
      await store.login('citizen@example.com', 'Demo12345!');
      final c = (await store.complaints().first).first;
      await store.register(
        'مواطن آخر',
        '777111222',
        'other@example.com',
        'Password123',
      );
      expect(await store.complaints().first, isEmpty);
      expect(() => store.setStatus(c, 'تم الحل'), throwsStateError);
    },
  );
  test('validation and serialization', () {
    expect(emailError('wrong'), isNotNull);
    expect(passwordError('123'), isNotNull);
    expect(requiredText('  '), isNotNull);
    expect(emailError('a@example.com'), isNull);
    final c = Complaint(
      id: '1',
      ownerId: 'a',
      ownerName: 'أحمد',
      title: 'عنوان',
      category: 'طرق',
      description: 'وصف',
      district: 'ذمار',
      created: DateTime(2026),
    );
    expect(Complaint.fromMap(c.id, c.toMap()).description, c.description);
  });
}
