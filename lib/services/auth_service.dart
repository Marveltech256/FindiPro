import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException {
      // Let the UI handle the exception to show a snackbar
      rethrow;
    }
  }

  Future<User?> registerClient({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? profileImageUrl,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        // This now creates a document in the 'users' collection
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': fullName,
          'email': email,
          'phone': phone,
          'role': 'client',
          'photoUrl': profileImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> registerProvider({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String category,
    required String location,
    required int yearsExperience,
    required String about,
    required String priceRange,
    String? profileImageUrl,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        // Create a document in the 'users' collection for auth purposes
        final userDoc = _firestore.collection('users').doc(user.uid);
        await userDoc.set({
          'uid': user.uid,
          'name': fullName,
          'email': email,
          'phone': phone,
          'role': 'provider',
          'photoUrl': profileImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create a document in the 'providers' collection with public business details
        final providerDoc = _firestore.collection('providers').doc(user.uid);
        await providerDoc.set({
          'uid': user.uid,
          'businessName': fullName, // Assuming fullName is the business name for now
          'category': category,
          'location': location,
          'experience': yearsExperience,
          'description': about,
          'hourlyRate': priceRange, // This mapping might need adjustment
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled the sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Check and create user in the 'users' collection
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final docSnapshot = await userDocRef.get();

        if (!docSnapshot.exists) {
          // New user, create a document in 'users' with role 'client' by default
          await userDocRef.set({
            'uid': user.uid,
            'name': user.displayName,
            'email': user.email,
            'phone': user.phoneNumber ?? '', // Phone number might not be available
            'role': 'client',
            'photoUrl': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    // Now fetches from the single 'users' collection
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      return userDoc.data() as Map<String, dynamic>;
    }

    return null;
  }
}