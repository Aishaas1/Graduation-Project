# إعداد Firebase

1. أنشئ مشروعًا في Firebase Console بحسابك. فعّل Authentication > Sign-in method > Email/Password.
2. أنشئ Firestore بوضع الإنتاج، وأنشئ Storage. تحقّق من خطة الفوترة المطلوبة في حسابك.
3. أضف تطبيق Web، وانسخ حقول Firebase config إلى نسخة من `firebase-config.example.json` باسم `firebase-config.json`. اجعل `DEMO` تساوي النص `false`. أضف نطاق موقعك في Authentication > Settings > Authorized domains.
4. استخدم بيانات تطبيق Web للويب. لأندرويد أضف تطبيقًا بالحزمة `ye.dhamar.dhamar_complaints`، واستخدم appId وapiKey الخاصين بتطبيق Android في ملف إعداد منفصل عند البناء له. يمكن استخدام FlutterFire CLI لاستخراج القيم الصحيحة. تطبيقنا يمرر FirebaseOptions صراحة ولا يتطلب google-services.json للتوثيق بالبريد.
5. ثبّت الأدوات وسجّل الدخول من جهازك:

```sh
npm ci
npx firebase login
npx firebase use --add
npx firebase deploy --only firestore:rules,storage
```

عند نشر قواعد Storage، وافق على تمكين وصولها إلى Firestore إذا طلبت المنصة ذلك؛ تحتاج القواعد التحقق من ملكية مستند الشكوى.

6. شغّل `flutter run -d chrome --dart-define-from-file=firebase-config.json` وسجّل حساب مواطن. تُنشأ وثيقة `users/{uid}` عند التسجيل.
7. لإنشاء مدير: سجّل حسابًا عاديًا أولًا، وانسخ UID من Authentication. على جهاز موثوق فقط، فعّل Application Default Credentials باستخدام gcloud، ثم:

```sh
gcloud auth application-default login
export GOOGLE_CLOUD_PROJECT=your-project-id
node tools/set-admin.mjs USER_UID
```

أو استخدم حساب خدمة مخزنًا خارج المستودع عبر `GOOGLE_APPLICATION_CREDENTIALS`. لا تضع أي سر في المحادثة أو GitHub. يجب أن يملك حساب التشغيل إذن تحديث مستخدمي Firebase Authentication. سجّل خروج المدير ثم دخوله للحصول على claim جديدة. الدور لا يُقرأ من حقل يستطيع المواطن تعديله.

8. لبناء واستضافة الويب:

```sh
flutter build web --dart-define-from-file=firebase-config.json
npx firebase deploy --only hosting
```

9. لبناء Android، ثبّت Android SDK واقبل التراخيص ثم نفّذ:

```sh
flutter doctor
flutter build apk --release --dart-define-from-file=firebase-config.android.json
```

القالب يستخدم توقيع debug عند بناء release لتسهيل التجربة. قبل النشر للمتجر، غيّر إعداد التوقيع إلى keystore إنتاج خاص بك، ولا ترفعه للمستودع.

## نموذج البيانات

- `users/{uid}`: الاسم والهاتف والبريد. التوثيق وكلمات المرور في Authentication.
- `complaints/{id}`: صاحب الشكوى والتفاصيل والحالة ومسارات المرفقات.
- `complaints/{id}/messages/{id}`: الرسالة أو حدث تغيير الحالة وهوية الكاتب والتوقيت.
- Storage: `complaints/{uid}/{complaintId}/{filename}`.

التحديثات مباشرة أثناء فتح التطبيق؛ لا توجد خدمة إشعارات دفع خارج التطبيق أو SMS. التوقيت يُرسل من الجهاز، لذلك لا يُعد سجل تدقيق قضائيًا. فحص نوع المرفق يعتمد على Content-Type؛ يلزم فحص برمجيات خبيثة ومحتوى الملفات عند استخدامه كخدمة عامة. روابط تنزيل Firebase المولدة عند فتح مرفق تحمل رمز وصول؛ تعامل معها كمعلومات خاصة ولا تشاركها. يلزم أيضًا وضع سياسة احتفاظ ونسخ احتياطي قبل تشغيل خدمة حكومية فعلية.

اختبر تسجيل مستخدمين مختلفين، ورفض قراءة شكوى مستخدم آخر، ومنح المدير صلاحية الرد وتحديث الحالة. المحاكيات تختبر القواعد دون اتصال بمشروع إنتاج. الرفع ليس معاملة واحدة بين Storage وFirestore؛ يحاول التطبيق تنظيف الشكوى والمرفقات إذا فشل الرفع. انقطاع التطبيق أثناء الرفع قد يترك مسودات أو ملفات تحتاج مراجعة الإدارة.
