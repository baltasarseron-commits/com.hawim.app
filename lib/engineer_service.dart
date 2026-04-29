import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo de datos para el Ingeniero
class Engineer {
  final String id; // Corresponderá al UID de Firebase Auth
  final String name;
  final String email;

  Engineer({required this.id, required this.name, required this.email});

  // Convertir un Engineer a un mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
    };
  }

  // Crear un Engineer desde un documento de Firestore
  factory Engineer.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Engineer(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
    );
  }
}

class EngineerService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // --- REGISTRO DE UN NUEVO USUARIO ---
  Future<String?> register(String name, String email, String pin) async {
    try {
      // 1. Crear el usuario en Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pin, // Usamos el PIN como contraseña
      );

      User? user = userCredential.user;

      if (user != null) {
        // 2. Guardar la información adicional (nombre) en Firestore
        await _firestore.collection('engineers').doc(user.uid).set({
          'name': name,
          'email': email,
        });
        notifyListeners();
        return null; // Sin errores
      }
      return "No se pudo crear el usuario.";

    } on FirebaseAuthException catch (e) {
      // Manejar errores comunes de Firebase Auth
      if (e.code == 'weak-password') {
        return 'El PIN es demasiado débil. Debe tener al menos 6 caracteres.';
      } else if (e.code == 'email-already-in-use') {
        return 'Este correo electrónico ya está registrado.';
      } else if (e.code == 'invalid-email') {
        return 'El formato del correo electrónico no es válido.';
      }
      return e.message; // Otro tipo de error
    } catch (e) {
      return 'Ha ocurrido un error inesperado durante el registro.';
    }
  }

  // --- INICIO DE SESIÓN ---
  Future<bool> login(String email, String pin) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: pin, // Usamos el PIN como contraseña
      );
      notifyListeners();
      return true; // Login exitoso
    } catch (e) {
      return false; // Error en el login
    }
  }

  // --- CERRAR SESIÓN ---
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  // --- RECUPERAR CONTRASEÑA (PIN) ---
  Future<String?> forgotPin(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return "No hay ningún usuario registrado con este correo electrónico.";
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // --- OBTENER DATOS DEL INGENIERO ACTUAL ---
  Future<Engineer?> getCurrentEngineerData() async {
    if (currentUser != null) {
      DocumentSnapshot doc = await _firestore.collection('engineers').doc(currentUser!.uid).get();
      if (doc.exists) {
        return Engineer.fromFirestore(doc);
      }
    }
    return null;
  }
}