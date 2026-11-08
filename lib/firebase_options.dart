import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDRs4pYvzlemesLk06vWiNJ16os0gxEQiA',
      appId: '1:515690430303:web:a5e555aefbde2efc14c0ea',
      messagingSenderId: '515690430303',
      projectId: 'jerseytude-billing',
      authDomain: 'jerseytude-billing.firebaseapp.com',
      storageBucket: 'jerseytude-billing.firebasestorage.app',
      measurementId: 'G-CCYRDGF6V5',
    );
  }
}
