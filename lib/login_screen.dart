import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'engineer_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  // Estado
  bool _isLoading = false;
  bool _isRegistering = false;

  // Animación
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _pinController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final engineerService = Provider.of<EngineerService>(context, listen: false);
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();

    String? errorMessage;

    if (_isRegistering) {
      final name = _nameController.text.trim();
      errorMessage = await engineerService.register(name, email, pin);
    } else {
      final success = await engineerService.login(email, pin);
      if (!success) {
        errorMessage = 'Email o PIN incorrecto.';
      }
    }

    if (mounted) {
      if (errorMessage == null) {
        // La navegación es manejada por el StreamBuilder en main.dart
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _formKey.currentState?.reset();
      _emailController.clear();
      _nameController.clear();
      _pinController.clear();
    });
  }

  void _forgotPin() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Introduce tu correo electrónico para recibir un enlace para restablecer tu PIN.'),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  final service = Provider.of<EngineerService>(context, listen: false);
                  final error = await service.forgotPin(email);
                  Navigator.of(context).pop(); // Cierra el diálogo
                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Se ha enviado un correo de recuperación.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Image.asset('assets/images/hawimIcon(f).png', height: 100),
                    const SizedBox(height: 24),
                    Text(
                      _isRegistering ? 'Crea tu Cuenta' : 'Bienvenido de Nuevo',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // --- CAMPO DE NOMBRE (SOLO EN MODO REGISTRO) ---
                    if (_isRegistering)
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
                        validator: (value) => (value ?? '').isEmpty ? 'Introduce tu nombre' : null,
                      ),
                    if (_isRegistering) const SizedBox(height: 16),

                    // --- CAMPO DE EMAIL ---
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
                      validator: (value) {
                        if ((value ?? '').isEmpty) return 'Introduce tu correo electrónico';
                        if (!value!.contains('@')) return 'Introduce un correo válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- CAMPO DE PIN ---
                    TextFormField(
                      controller: _pinController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'PIN (mín. 6 caracteres)', border: OutlineInputBorder()),
                      validator: (value) => (value?.length ?? 0) < 6 ? 'El PIN debe tener al menos 6 caracteres' : null,
                    ),
                    const SizedBox(height: 24),

                    // --- BOTÓN DE SUBMIT ---
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _submit,
                            child: Text(_isRegistering ? 'Registrarse' : 'Iniciar Sesión'),
                          ),
                    const SizedBox(height: 16),

                    // --- BOTÓN PARA CAMBIAR DE MODO Y OLVIDÉ PIN ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(_isRegistering ? '¿Ya tienes cuenta? Inicia Sesión' : '¿No tienes cuenta? Regístrate'),
                        ),
                        if (!_isRegistering) // Solo mostrar si no se está registrando
                          TextButton(
                            onPressed: _forgotPin,
                            child: const Text('Olvidé mi PIN'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
