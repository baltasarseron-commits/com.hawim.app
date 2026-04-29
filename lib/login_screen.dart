import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _forgotPinEmailController = TextEditingController();

  // Nodos de Foco
  final _emailFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();
  final _pinFocusNode = FocusNode();

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
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _pinController.dispose();
    _forgotPinEmailController.dispose();
    _emailFocusNode.dispose();
    _nameFocusNode.dispose();
    _pinFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _unfocusAll() {
    _emailFocusNode.unfocus();
    _nameFocusNode.unfocus();
    _pinFocusNode.unfocus();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _unfocusAll();
    setState(() => _isLoading = true);

    final engineerService = Provider.of<EngineerService>(context, listen: false);
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();

    String? errorMessage;
    bool registrationSuccess = false;

    if (_isRegistering) {
      final name = _nameController.text.trim();
      errorMessage = await engineerService.register(name, email, pin);
      if (errorMessage == null) {
        registrationSuccess = true;
      }
    } else {
      final success = await engineerService.login(email, pin);
      if (mounted && success) {
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      } else if (!success) {
        errorMessage = 'Email o PIN incorrecto.';
      }
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (registrationSuccess) {
      _toggleMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Registro exitoso! Ahora puedes iniciar sesión.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  void _toggleMode() {
    _unfocusAll();
    setState(() {
      _isRegistering = !_isRegistering;
      _formKey.currentState?.reset();
      _emailController.clear();
      _nameController.clear();
      _pinController.clear();
    });
  }

  void _forgotPin() {
    _forgotPinEmailController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Introduce tu correo para reestablecer tu PIN.'),
              const SizedBox(height: 16),
              TextField(
                controller: _forgotPinEmailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
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
                final email = _forgotPinEmailController.text.trim();
                if (email.isNotEmpty) {
                  final service =
                      Provider.of<EngineerService>(context, listen: false);
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final error = await service.forgotPin(email);

                  if (!mounted) return;
                  navigator.pop();

                  if (error == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content:
                            Text('Se ha enviado un correo de recuperación.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
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
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    if (_isRegistering)
                      TextFormField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        decoration: const InputDecoration(
                            labelText: 'Nombre Completo',
                            border: OutlineInputBorder()),
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Introduce tu nombre'
                            : null,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_emailFocusNode);
                        },
                      ),
                    if (_isRegistering) const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9@._-]')),
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          border: OutlineInputBorder()),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Introduce tu correo electrónico';
                        }
                        final emailRegex = RegExp(
                            r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Introduce un correo válido';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_pinFocusNode);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pinController,
                      focusNode: _pinFocusNode,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'PIN (mín. 6 caracteres)',
                          border: OutlineInputBorder()),
                      validator: (value) => (value?.length ?? 0) < 6
                          ? 'El PIN debe tener al menos 6 caracteres'
                          : null,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _submit,
                            child: Text(_isRegistering
                                ? 'Registrarse'
                                : 'Iniciar Sesión'),
                          ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(_isRegistering
                              ? '¿Ya tienes cuenta? Inicia Sesión'
                              : '¿No tienes cuenta? Regístrate'),
                        ),
                        if (!_isRegistering)
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
