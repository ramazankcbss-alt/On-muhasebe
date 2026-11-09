import 'package:firebase_core/firebase_core.dart';

/// kones-muhasebe Firebase projesinin Android istemci ayarları.
/// Bunlar gizli anahtar değildir; uygulamanın hangi projeye bağlanacağını söyler.
/// Verinin güvenliği Firestore kurallarıyla (firestore.rules) sağlanır.
const firebaseAyar = FirebaseOptions(
  apiKey: 'AIzaSyDnaLDbCBoqrhbrk7zmkUhqHUhfsrDNm-k',
  appId: '1:207268468862:android:df5c5b864ac76dc68f602f',
  messagingSenderId: '207268468862',
  projectId: 'kones-muhasebe',
  storageBucket: 'kones-muhasebe.firebasestorage.app',
);
