import 'dart:ui';
import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _aliasController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedBloodType;
  final List<String> _bloodTypes = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  String _selectedRole = 'donor_recipient'; // Default role
  final List<Map<String, String>> _roles = [
    {'value': 'donor_recipient', 'label': 'Donor / Recipient'},
    {'value': 'admin', 'label': 'System Admin'},
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _aliasController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRole == 'donor_recipient' && _selectedBloodType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your blood type.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
        return;
      }

      final roleLabel = _selectedRole == 'admin' ? 'System Admin' : 'Donor/Recipient';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registered successfully as $roleLabel! Welcome to TABANG.'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ==============================================
          // BACKGROUND CONTENT (Split Layout)
          // ==============================================
          Column(
            children: [
              const SizedBox(height: 70), // Spacer for transparent header overlay
              Expanded(
                child: Row(
                  children: [
                    // Left Crimson Panel
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF8E2124),
                              Color(0xFF7A1C1E),
                              Color(0xFF5D1214),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            const Text(
                              'Your single bag of blood can\nsave up to three lives.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                                fontFamily: 'serif',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Every day, patients across the Philippines need urgent blood\ntransfusions. By registering as a voluntary donor, you become their\nhero in waiting.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 35),
                            const Text(
                              '1.2 Million',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Bags needed annually',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'The nationwide requirement to secure healthy blood reserves for emergencies.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10.5,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(color: Colors.white24, thickness: 1),
                            ),
                            const Text(
                              '588,575',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Units collected last year',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Every contribution helps close the persistent gap to serve those in dire need.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10.5,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),

                    // Right Form Panel
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: Colors.white,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 420),
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE5E5EA)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Center(
                                      child: Text(
                                        'Register',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'To protect your data privacy, only your nickname, blood type, and barangay will be shown when interacting with other users.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.black54,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Account Type / Role Dropdown
                                    _fieldLabel('Account Type / Role'),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: _selectedRole,
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      decoration: _mockupInputDecor('Select Role'),
                                      items: _roles.map((role) {
                                        return DropdownMenuItem(
                                          value: role['value'],
                                          child: Text(
                                            role['label']!,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedRole = val);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Full Name
                                    _fieldLabel('Full Name'),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _fullNameController,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: _mockupInputDecor('Briones, Iverson D.'),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    // Nickname/Alias
                                    _fieldLabel('Nickname/Alias'),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _aliasController,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: _mockupInputDecor('Iver'),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    // Email Address
                                    _fieldLabel('Email Address'),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _emailController,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: _mockupInputDecor('iversonbriones@gmail.com'),
                                      validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    // Password
                                    _fieldLabel('Password'),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: _mockupInputDecor('••••••••'),
                                      validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    // Contact Number
                                    _fieldLabel('Contact Number'),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _phoneController,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: _mockupInputDecor('09123456789'),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    // Birth Date & Blood Type Row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _fieldLabel('Birth Date'),
                                              const SizedBox(height: 4),
                                              TextFormField(
                                                controller: _birthDateController,
                                                style: const TextStyle(fontSize: 12),
                                                decoration: _mockupInputDecor('MM / DD / YYYY'),
                                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _fieldLabel('Blood Type'),
                                              const SizedBox(height: 4),
                                              DropdownButtonFormField<String>(
                                                value: _selectedBloodType,
                                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                hint: Text('Select Blood Type', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                                decoration: _mockupInputDecor(''),
                                                items: _bloodTypes.map((type) {
                                                  return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 12)));
                                                }).toList(),
                                                onChanged: _selectedRole == 'admin'
                                                    ? null
                                                    : (val) => setState(() => _selectedBloodType = val),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // City Address
                                    _fieldLabel('City Address'),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _addressController,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: _mockupInputDecor('Barangay, City, Province'),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 20),

                                    // Submit Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 38,
                                      child: ElevatedButton(
                                        onPressed: _handleRegister,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2C2C2C),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        child: const Text(
                                          'Submit',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ==============================================
          // 70% TRANSPARENT FLOATING TOP HEADER BAR
          // ==============================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _topNavLink('Home'),
                      const SizedBox(width: 36),
                      _topNavLink('Features'),
                      const SizedBox(width: 36),
                      _topNavLink('About'),
                      const SizedBox(width: 36),
                      _topNavLink('Contact'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topNavLink(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFamily: 'serif',
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );
  }

  InputDecoration _mockupInputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF7A1C1E), width: 1.5),
      ),
    );
  }
}