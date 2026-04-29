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

  // Variables para el modo de Login
  String? _selectedEngineerId;

  // Variables para el modo de Registro
  final _nameController = TextEditingController();

  // Variables comunes
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false; // Controla el modo (Login vs. Registro)

  // Animación
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Cargar ingenieros sin notificar a los listeners
    Provider.of<EngineerService>(context, listen: false).fetchEngineers();

    // Configuración de la animación
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeInOut),
    );

    // Iniciar la animación
    _animationController.forward();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final engineerService =
        Provider.of<EngineerService>(context, listen: false);
    final pin = _pinController.text;

    if (_isRegistering) {
      // --- Lógica de Registro ---
      final name = _nameController.text;
      final errorMessage = await engineerService.register(name, pin);

      if (mounted) {
        if (errorMessage == null) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // --- Lógica de Login ---
      if (_selectedEngineerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, seleccione un/a ingeniero/a.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      final success = await engineerService.login(_selectedEngineerId!, pin);

      if (mounted) {
        if (success) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN o Ingeniero incorrecto. Inténtelo de nuevo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      // Limpia el estado del formulario y los controladores al cambiar de modo
      _formKey.currentState?.reset();
      _pinController.clear();
      _nameController.clear();
      _selectedEngineerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isRegistering ? 'Registro' : 'Inicio de Sesión')),
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
                    // --- ICONO DE LA APP ---
                    Image.asset(
                      'assets/images/hawimIcon(f).png',
                      height: 120,
                      width: 120,
                    ),
                    const SizedBox(height: 30),

                    // --- CAMPO DE NOMBRE (SOLO EN MODO REGISTRO) ---
                    if (_isRegistering)
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) =>
                            _isRegistering && (value == null || value.isEmpty)
                                ? 'Introduzca su nombre'
                                : null,
                      )
                    else
                      // --- DROPDOWN DE INGENIEROS (SOLO EN MODO LOGIN) ---
                      Consumer<EngineerService>(
                        builder: (context, engineerService, child) {
                          if (engineerService.engineers.isEmpty &&
                              !engineerService.isLoading) {
                            return const Text(
                                'No hay ingenieros registrados. Por favor, regístrese.',
                                textAlign: TextAlign.center);
                          }
                          if (engineerService.isLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Ingeniero/a',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedEngineerId,
                            items: engineerService.engineers.map((engineer) {
                              return DropdownMenuItem<String>(
                                value: engineer.id,
                                child: Text(engineer.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedEngineerId = value;
                              });
                            },
                            validator: (value) => !_isRegistering && value == null
                                ? 'Seleccione un/a ingeniero/a'
                                : null,
                          );
                        },
                      ),
                    const SizedBox(height: 20),

                    // --- CAMPO DE PIN (COMÚN) ---
                    TextFormField(
                      controller: _pinController,
                      decoration: const InputDecoration(
                        labelText: 'PIN (Numérico)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, introduzca su PIN';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // --- BOTÓN DE SUBMIT (DINÁMICO) ---
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: Text(_isRegistering ? 'Registrar' : 'Entrar'),
                      ),
                    const SizedBox(height: 20),

                    // --- BOTÓN PARA CAMBIAR DE MODO ---
                    TextButton(
                      onPressed: _toggleMode,
                      child: Text(_isRegistering
                          ? '¿Ya tienes una cuenta? Inicia sesión'
                          : '¿Eres nuevo/a? Regístrate aquí'),
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
