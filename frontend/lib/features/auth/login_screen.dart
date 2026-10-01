import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Login Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Register Controllers
  final _regFirstNameController = TextEditingController();
  final _regLastNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regAgeController = TextEditingController();
  String _selectedRole = 'PATIENT';

  int _selectedTab = 0; // 0 = Login, 1 = Register
  bool _isSubmitting = false;
  bool _obscureLoginPassword = true;
  bool _obscureRegPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _regFirstNameController.dispose();
    _regLastNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regPhoneController.dispose();
    _regAgeController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال البريد الإلكتروني وكلمة المرور.'),
          backgroundColor: AppTheme.alertRose,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await auth.login(email, password);
      if (success && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'فشل تسجيل الدخول. تحقق من البيانات.'),
            backgroundColor: AppTheme.alertRose,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الاتصال بالخادم: $e'),
            backgroundColor: AppTheme.alertRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitRegister() async {
    final firstName = _regFirstNameController.text.trim();
    final lastName = _regLastNameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text.trim();
    final phone = _regPhoneController.text.trim();
    final ageText = _regAgeController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty || ageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة للتسجيل بما فيها العمر ورقم الهاتف.'),
          backgroundColor: AppTheme.alertRose,
        ),
      );
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null || age < 12 || age > 110) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال عمر صحيح بين 12 و 110 سنة.'),
          backgroundColor: AppTheme.alertRose,
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleanPhone.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم هاتف صالح يتكون من 7 أرقام على الأقل.'),
          backgroundColor: AppTheme.alertRose,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن تتكون كلمة المرور من 6 خانات على الأقل.'),
          backgroundColor: AppTheme.alertRose,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final regSuccess = await auth.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: _selectedRole,
        phoneNumber: cleanPhone,
        age: age,
      );

      if (regSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الحساب بنجاح! مرحباً بك في المنصة.'),
            backgroundColor: AppTheme.sageGreen,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'فشل إنشاء الحساب. تحقق من البيانات المدخلة.'),
            backgroundColor: AppTheme.alertRose,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء التسجيل: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Clinical Brand Logo & Emblem
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryTeal.withValues(alpha: 0.15),
                          AppTheme.oceanAzure.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.25), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.psychology_outlined,
                          size: 42,
                          color: AppTheme.primaryTeal,
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppTheme.sageGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Platform Title & Slogan
                const Text(
                  'منصة الرعاية النفسية والتقييم الذكي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slateNavy,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 22),

                // Card Container for Auth
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tab Switcher
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.slateLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedTab = 0),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _selectedTab == 0
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'تسجيل الدخول',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _selectedTab == 0 ? AppTheme.primaryTealDark : AppTheme.slateMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedTab = 1),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _selectedTab == 1
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'حساب جديد',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _selectedTab == 1 ? AppTheme.primaryTealDark : AppTheme.slateMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form Content
                        if (_selectedTab == 0)
                          // LOGIN FORM
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'البريد الإلكتروني',
                                  hintText: 'name@example.com',
                                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscureLoginPassword,
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureLoginPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: AppTheme.slateMuted,
                                    ),
                                    onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('لاستعادة كلمة المرور، يرجى التواصل مع الدعم الفني أو الطبيب المشرف.'),
                                        backgroundColor: AppTheme.primaryTeal,
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                  child: const Text(
                                    'نسيت كلمة المرور؟',
                                    style: TextStyle(fontSize: 11.5, color: AppTheme.primaryTealDark, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitLogin,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('تسجيل الدخول', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        else
                          // REGISTER FORM
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _regFirstNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'الاسم الأول *',
                                        prefixIcon: Icon(Icons.person_outline, size: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _regLastNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'اسم العائلة *',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'نوع الحساب',
                                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'PATIENT',
                                    child: Text('مريض (Patient)', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'DOCTOR',
                                    child: Text('طبيب / أخصائي نفسي (Doctor)', overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _selectedRole = val!),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _regEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'البريد الإلكتروني الجديد *',
                                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: TextField(
                                        controller: _regPhoneController,
                                        keyboardType: TextInputType.phone,
                                        decoration: const InputDecoration(
                                          labelText: 'رقم الهاتف *',
                                          hintText: '09XXXXXXXX',
                                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _regAgeController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'العمر *',
                                        hintText: 'مثال: 24',
                                        prefixIcon: Icon(Icons.cake_outlined, size: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _regPasswordController,
                                obscureText: _obscureRegPassword,
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور * (6 خانات أو أكثر)',
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureRegPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: AppTheme.slateMuted,
                                    ),
                                    onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitRegister,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('إنشاء الحساب الآن', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

