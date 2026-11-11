const statuses = ['جديدة', 'قيد المراجعة', 'قيد المعالجة', 'تم الحل', 'مرفوضة'];
const categories = [
  'خدمات عامة',
  'فساد إداري',
  'مياه وصرف صحي',
  'كهرباء',
  'طرق',
  'صحة',
  'تعليم',
  'أخرى',
];

class Account {
  final String id, name, email, phone;
  final bool admin;
  const Account(
    this.id,
    this.name,
    this.email,
    this.phone, {
    this.admin = false,
  });
}

class Complaint {
  final String id, ownerId, ownerName, title, category, description, district;
  final String accused, employer, accusedPhone;
  final DateTime created;
  String status;
  List<Map<String, String>> attachments;
  Complaint({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.category,
    required this.description,
    required this.district,
    this.accused = '',
    this.employer = '',
    this.accusedPhone = '',
    required this.created,
    this.status = 'جديدة',
    this.attachments = const [],
  });
  Map<String, dynamic> toMap() => {
    'ownerId': ownerId,
    'ownerName': ownerName,
    'title': title,
    'category': category,
    'description': description,
    'district': district,
    'accused': accused,
    'employer': employer,
    'accusedPhone': accusedPhone,
    'created': created.toIso8601String(),
    'status': status,
    'attachments': attachments,
  };
  factory Complaint.fromMap(String id, Map<String, dynamic> m) => Complaint(
    id: id,
    ownerId: m['ownerId'],
    ownerName: m['ownerName'],
    title: m['title'],
    category: m['category'],
    description: m['description'],
    district: m['district'],
    accused: m['accused'] ?? '',
    employer: m['employer'] ?? '',
    accusedPhone: m['accusedPhone'] ?? '',
    created: DateTime.parse(m['created']),
    status: m['status'],
    attachments: (m['attachments'] as List? ?? [])
        .map((e) => Map<String, String>.from(e))
        .toList(),
  );
}

class Entry {
  final String author, text, senderId;
  final DateTime time;
  final bool event;
  Entry(this.author, this.text, this.senderId, this.time, {this.event = false});
  Map<String, dynamic> toMap() => {
    'author': author,
    'text': text,
    'senderId': senderId,
    'time': time.toIso8601String(),
    'event': event,
  };
  factory Entry.fromMap(Map<String, dynamic> m) => Entry(
    m['author'],
    m['text'],
    m['senderId'],
    DateTime.parse(m['time']),
    event: m['event'] ?? false,
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;
String? emailError(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'أدخل بريدًا إلكترونيًا صحيحًا';
String? passwordError(String? value) =>
    (value?.length ?? 0) >= 8 ? null : 'كلمة المرور 8 أحرف على الأقل';
