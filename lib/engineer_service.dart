import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Engineer {
  final String id;
  final String name;

  Engineer({required this.id, required this.name});

  factory Engineer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Engineer(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }
}

class EngineerService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Engineer? _currentEngineer;
  List<Engineer> _engineers = [];
  bool _isLoading = false;

  Engineer? get currentEngineer => _currentEngineer;
  List<Engineer> get engineers => _engineers;
  bool get isLoading => _isLoading;

  Future<void> fetchEngineers() async {
    _isLoading = true;
    // By awaiting a zero-duration delay, we allow the current build cycle
    // to complete before calling notifyListeners(), which resolves the error.
    await Future.delayed(Duration.zero);
    notifyListeners();
    
    try {
      final snapshot = await _firestore.collection('engineers').get();
      _engineers = snapshot.docs.map((doc) => Engineer.fromFirestore(doc)).toList();
    } catch (e, s) {
      developer.log("Error fetching engineers", error: e, stackTrace: s);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String engineerId, String pin) async {
    try {
      final doc = await _firestore.collection('engineers').doc(engineerId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['pin'] == pin) {
          _currentEngineer = Engineer.fromFirestore(doc);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e, s) {
      developer.log("Error logging in", error: e, stackTrace: s);
      return false;
    }
  }

  Future<String?> register(String name, String pin) async {
    try {
      final querySnapshot = await _firestore
          .collection('engineers')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return 'Ya existe un/a ingeniero/a con este nombre.';
      }

      final newEngineerRef = await _firestore.collection('engineers').add({
        'name': name,
        'pin': pin,
      });

      _currentEngineer = Engineer(id: newEngineerRef.id, name: name);
      
      await fetchEngineers();

      return null;
    } catch (e, s) {
      developer.log("Error registering engineer", error: e, stackTrace: s);
      return 'Ocurrió un error durante el registro.';
    }
  }

  void logout() {
    _currentEngineer = null;
    notifyListeners();
  }
}
