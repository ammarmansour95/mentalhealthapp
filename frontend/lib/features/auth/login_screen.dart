import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/api_service.dart';

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
  final _regPhoneController = TextEditingController(text: '09');
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

  void _fillDemo(String email, String password, String role) {
    setState(() {
      _selectedTab = 0;
      _emailController.text = email;
      _passwordController.text = password;
    });
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
    if (!cleanPhone.startsWith('09') && !cleanPhone.startsWith('+963') && !cleanPhone.startsWith('9')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم هاتف جوال سوري صالح يبدأ بـ 09 أو +963 (مثال: 0933123456).'),
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
      final otpRes = await ApiService.post('/auth/phone/send-otp/', {
        'phone_number': cleanPhone,
      });

      setState(() => _isSubmitting = false);

      if (otpRes['success'] == true && mounted) {
        final devOtp = otpRes['dev_otp']?.toString() ?? '';
        final normPhone = otpRes['phone_number']?.toString() ?? cleanPhone;
        _showOtpVerificationDialog(
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
          normalizedPhone: normPhone,
          age: age,
          devOtp: devOtp,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(otpRes['message'] ?? 'فشل إرسال رمز التحقق.'),
            backgroundColor: AppTheme.alertRose,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إرسال الرمز: $e'), backgroundColor: AppTheme.alertRose),
        );
      }
    }
  }

  void _showOtpVerificationDialog({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String normalizedPhone,
    required int age,
    required String devOtp,
  }) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_outlined, color: AppTheme.primaryTeal, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'التحقق من رقم الهاتف 🇸🇾',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.slateNavy),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تم إرسال رمز تحقق مؤقت (SMS) إلى رقم هاتفك السوري للضرورة السريرية وحالات الطوارئ:',
                  style: TextStyle(fontSize: 12, color: AppTheme.slateMuted, height: 1.4),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_android, size: 16, color: AppTheme.primaryTeal),
                      const SizedBox(width: 6),
                      Text(
                        normalizedPhone,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryTealDark),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
                  decoration: InputDecoration(
                    labelText: 'رمز التحقق (6 أرقام)',
                    hintText: '••••••',
                    errorText: errorText,
                    prefixIcon: const Icon(Icons.security, size: 20),
                  ),
                ),
                if (devOtp.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setModalState(() => otpController.text = devOtp),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.sageGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '💡 تجريبي: اضغط لتعبئة رمز الاختبار السريع ($devOtp)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.sageGreen),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(ctx),
              child: const Text('تراجع', style: TextStyle(color: AppTheme.slateMuted)),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final code = otpController.text.trim();
                      if (code.length != 6) {
                        setModalState(() => errorText = 'أدخل الرمز كاملاً (6 أرقام)');
                        return;
                      }

                      setModalState(() {
                        isVerifying = true;
                        errorText = null;
                      });

                      try {
                        final vRes = await ApiService.post('/auth/phone/verify-otp/', {
                          'phone_number': normalizedPhone,
                          'otp_code': code,
                        });

                        if (vRes['success'] == true) {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final regSuccess = await auth.register(
                            email: email,
                            password: password,
                            firstName: firstName,
                            lastName: lastName,
                            role: _selectedRole,
                            phoneNumber: normalizedPhone,
                            age: age,
                          );

                          if (regSuccess && mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تأكيد رقم الهاتف وإنشاء الحساب بنجاح! مرحباً بك.'),
                                backgroundColor: AppTheme.sageGreen,
                              ),
                            );
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          } else if (mounted) {
                            setModalState(() {
                              isVerifying = false;
                              errorText = auth.errorMessage ?? 'فشل تسجيل الحساب';
                            });
                          }
                        } else {
                          setModalState(() {
                            isVerifying = false;
                            errorText = vRes['message'] ?? 'الرمز غير صحيح';
                          });
                        }
                      } catch (e) {
                        setModalState(() {
                          isVerifying = false;
                          errorText = 'خطأ في التحقق: $e';
                        });
                      }
                    },
              child: isVerifying
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تأكيد وإنشاء الحساب'),
            ),
          ],
        ),
      ),
    );
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
                // Brand Icon
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.spa_outlined,
                      size: 38,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Platform Title & Slogan
                const Text(
                  'منصة الرعاية النفسية والتشخيص الذكي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slateNavy,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'مساحة آمنة للتقييم الأولي والاستشارات السريرية المعتمدة 🌿',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.slateMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

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
                              const SizedBox(height: 20),
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
                                          prefixIcon: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 10),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('🇸🇾 +963', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slateNavy)),
                                              ],
                                            ),
                                          ),
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

                const SizedBox(height: 20),
                // Quick Demo Account Buttons with exact database passwords
                const Text(
                  'أو اختر أحد الحسابات التجريبية للتجربة السريعة:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.slateMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.person, size: 15, color: AppTheme.primaryTeal),
                      label: const Text('مريض (Patient)', style: TextStyle(fontSize: 11.5)),
                      onPressed: () => _fillDemo('patient@mentalhealth.com', 'Pass@123', 'PATIENT'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.medical_services, size: 15, color: AppTheme.oceanAzure),
                      label: const Text('طبيب معتمد (Doctor)', style: TextStyle(fontSize: 11.5)),
                      onPressed: () => _fillDemo('dr.sarah@mentalhealth.com', 'Pass@123', 'DOCTOR'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.admin_panel_settings, size: 15, color: AppTheme.slateNavy),
                      label: const Text('مدير المنصة (Admin)', style: TextStyle(fontSize: 11.5)),
                      onPressed: () => _fillDemo('admin@mentalhealth.com', 'Admin@123', 'ADMIN'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
