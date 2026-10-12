import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import 'login.dart';

const int kTotalSteps = 5;

/// -----------------------------------------------------------------------
/// REGISTER PAGE
/// -----------------------------------------------------------------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int currentStep = 0;

  final AuthService _authService = AuthService();
  final AddressService _addressService = AddressService();
  final SessionManager _session = SessionManager();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSubmitting = false;

  // Each step has its own form key so we can validate independently.
  final List<GlobalKey<FormState>> _formKeys =
      List.generate(kTotalSteps, (_) => GlobalKey<FormState>());

  // ---------------- Step 1: Get to know you ----------------
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final middleInitialCtrl = TextEditingController();

  // ---------------- Step 2: More about you ----------------
  String? sex;
  DateTime? birthday;
  int? age;

  // ---------------- Step 3: Reach you + account ----------------
  final emailCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ---------------- Step 4: Address (PSGC-backed dropdowns) ----------------
  List<Province> provinces = [];
  List<Municipality> municipalities = [];
  List<Barangay> barangays = [];
  bool provincesLoading = false;
  bool municipalitiesLoading = false;
  bool barangaysLoading = false;

  Province? selectedProvince;
  Municipality? selectedMunicipality;
  Barangay? selectedBarangay;

  final streetCtrl = TextEditingController();
  final houseNumberCtrl = TextEditingController();

  // ---------------- Step 5: Verification ----------------
  File? idFile; // the actual picked file, sent via MultipartRequest

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    middleInitialCtrl.dispose();
    emailCtrl.dispose();
    contactCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    streetCtrl.dispose();
    houseNumberCtrl.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // ADDRESS DATA LOADING (PSGC API)
  // -----------------------------------------------------------------
  Future<void> _loadProvinces() async {
    setState(() => provincesLoading = true);
    try {
      final result = await _addressService.getProvinces();
      if (!mounted) return;
      setState(() => provinces = result);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not load provinces: $e');
    } finally {
      if (mounted) setState(() => provincesLoading = false);
    }
  }

  Future<void> _loadMunicipalities(Province province) async {
    setState(() {
      municipalitiesLoading = true;
      municipalities = [];
      barangays = [];
      selectedMunicipality = null;
      selectedBarangay = null;
    });
    try {
      final result = await _addressService.getMunicipalities(province.code);
      if (!mounted) return;
      setState(() => municipalities = result);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not load municipalities: $e');
    } finally {
      if (mounted) setState(() => municipalitiesLoading = false);
    }
  }

  Future<void> _loadBarangays(Municipality municipality) async {
    setState(() {
      barangaysLoading = true;
      barangays = [];
      selectedBarangay = null;
    });
    try {
      final result = await _addressService.getBarangays(municipality.code);
      if (!mounted) return;
      setState(() => barangays = result);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not load barangays: $e');
    } finally {
      if (mounted) setState(() => barangaysLoading = false);
    }
  }

  // -----------------------------------------------------------------
  // NAVIGATION LOGIC
  // -----------------------------------------------------------------
  void _goNext() {
    // Validate current step's form (steps without a Form always pass).
    final formState = _formKeys[currentStep].currentState;
    final isValid = formState?.validate() ?? true;
    if (!isValid) return;

    // Extra manual check for step 2 (dropdown / date aren't part of Form
    // validators here, kept simple — feel free to wire them into the
    // Form with FormField if you want built-in validation messages).
    if (currentStep == 1 && (sex == null || birthday == null)) {
      _showSnack('Please complete sex and birthday');
      return;
    }
    if (currentStep == 3 &&
        (selectedProvince == null ||
            selectedMunicipality == null ||
            selectedBarangay == null)) {
      _showSnack('Please complete all address dropdowns');
      return;
    }
    if (currentStep == 4 && idFile == null) {
      _showSnack('Please upload a valid ID before submitting');
      return;
    }

    if (currentStep < kTotalSteps - 1) {
      setState(() => currentStep++);
    } else {
      _submitRegistration();
    }
  }

  void _goBack() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // -----------------------------------------------------------------
  // ID PICKER (camera or gallery, jpg/png — see README for adding PDF
  // support with the file_picker package)
  // -----------------------------------------------------------------
  Future<void> _pickId() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() => idFile = File(picked.path));
  }

  // -----------------------------------------------------------------
  // SUBMIT: register() -> upload-id() -> pending approval screen
  // -----------------------------------------------------------------
  Future<void> _submitRegistration() async {
    setState(() => _isSubmitting = true);

    final result = await _authService.register(
      firstName: firstNameCtrl.text.trim(),
      lastName: lastNameCtrl.text.trim(),
      middleInitial: middleInitialCtrl.text.trim(),
      sex: sex!,
      email: emailCtrl.text.trim(),
      password: passwordCtrl.text,
      passwordConfirmation: confirmPasswordCtrl.text,
      contactNo: contactCtrl.text.trim(),
      birthday:
          '${birthday!.year}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}',
      province: selectedProvince!.name,
      municipality: selectedMunicipality!.name,
      barangay: selectedBarangay!.name,
      street: streetCtrl.text.trim(),
      houseNo: houseNumberCtrl.text.trim(),
    );

    if (!result.success) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnack(result.firstError ?? result.message);
      return;
    }

    final user = result.data?['user'] as Map<String, dynamic>?;
    final token = result.data?['token'] as String?;
    final userId = user?['id'] as int?;

    if (user != null && token != null && userId != null) {
      await _session.save(
        token: token,
        userId: userId,
        name: user['name']?.toString() ?? '',
        email: user['email']?.toString() ?? '',
      );
    }

    // Now upload the ID file, tied to the newly created user.
    if (userId != null && idFile != null) {
      final uploadResult =
          await _authService.uploadId(userId: userId, file: idFile!);
      if (!uploadResult.success) {
        // Account was created but ID upload failed — let the user know
        // rather than silently dropping it. They can retry from a
        // "complete your profile" screen later.
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showSnack(
          'Account created, but ID upload failed: ${uploadResult.message}',
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _PendingApprovalPage()),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _PendingApprovalPage()),
    );
  }

  // -----------------------------------------------------------------
  // BUILD
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) {
                    final offsetAnim = Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnim,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(currentStep),
                    child: buildStepContent(),
                  ),
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // TOP BAR: back button + progress
  // -----------------------------------------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.label),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${currentStep + 1} of $kTotalSteps',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.hint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / kTotalSteps,
              minHeight: 6,
              backgroundColor: AppColors.progressBg,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // BOTTOM BUTTON
  // -----------------------------------------------------------------
  Widget _buildBottomButton() {
    final isLastStep = currentStep == kTotalSteps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _goNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  isLastStep ? 'Submit Registration' : 'Continue',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // STEP ROUTER
  // -----------------------------------------------------------------
  Widget buildStepContent() {
    switch (currentStep) {
      case 0:
        return _step1();
      case 1:
        return _step2();
      case 2:
        return _step3();
      case 3:
        return _step4();
      case 4:
        return _step5();
      default:
        return const SizedBox.shrink();
    }
  }

  // ===================================================================
  // STEP 1 — Get to know you
  // ===================================================================
  Widget _step1() {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('Step 1: Get to know you'),
          const SizedBox(height: 20),
          _LabeledField(
            label: 'First name',
            child: _TextInput(
              controller: firstNameCtrl,
              hint: 'First name',
              validator: _requiredValidator,
            ),
          ),
          _LabeledField(
            label: 'Last name',
            child: _TextInput(
              controller: lastNameCtrl,
              hint: 'Last name',
              validator: _requiredValidator,
            ),
          ),
          _LabeledField(
            label: 'Middle Initial',
            child: _TextInput(
              controller: middleInitialCtrl,
              hint: 'M.I.',
              maxLength: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // STEP 2 — More about you
  // ===================================================================
  Widget _step2() {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('Step 2: More about you'),
          const SizedBox(height: 20),
          _LabeledField(
            label: 'Sex',
            child: _Dropdown<String>(
              value: sex,
              hint: 'Sex',
              items: const ['Male', 'Female', 'Prefer not to say'],
              onChanged: (v) => setState(() => sex = v),
            ),
          ),
          _LabeledField(
            label: 'Birthday',
            child: _DatePickerField(
              value: birthday,
              hint: 'Birthday',
              onPicked: (date) {
                setState(() {
                  birthday = date;
                  age = _calculateAge(date);
                });
              },
            ),
          ),
          _LabeledField(
            label: 'Age',
            child: _TextInput(
              controller: TextEditingController(text: age?.toString() ?? ''),
              hint: 'Age',
              enabled: false,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int calculatedAge = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  // ===================================================================
  // STEP 3 — Reach you + account security
  // ===================================================================
  Widget _step3() {
    return Form(
      key: _formKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('Step 3: Reach you'),
          const SizedBox(height: 20),
          _LabeledField(
            label: 'Email',
            child: _TextInput(
              controller: emailCtrl,
              hint: 'email@yourmail.com',
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
          ),
          _LabeledField(
            label: 'Contact number',
            child: _TextInput(
              controller: contactCtrl,
              hint: '+123-455-7890',
              keyboardType: TextInputType.phone,
              validator: _requiredValidator,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
              ],
            ),
          ),
          _LabeledField(
            label: 'Password',
            child: _TextInput(
              controller: passwordCtrl,
              hint: 'At least 8 characters',
              obscureText: _obscurePassword,
              validator: _passwordValidator,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.hint,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          _LabeledField(
            label: 'Confirm password',
            child: _TextInput(
              controller: confirmPasswordCtrl,
              hint: 'Re-enter your password',
              obscureText: _obscureConfirmPassword,
              validator: _confirmPasswordValidator,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.hint,
                ),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // STEP 4 — Address (live PSGC dropdowns: province -> municipality -> barangay)
  // ===================================================================
  Widget _step4() {
    return Form(
      key: _formKeys[3],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('Step 4: Send orders'),
          const SizedBox(height: 20),
          _LabeledField(
            label: 'Province',
            child: provincesLoading
                ? const _DropdownLoading()
                : _Dropdown<Province>(
                    value: selectedProvince,
                    hint: 'Province',
                    items: provinces,
                    onChanged: (v) {
                      setState(() => selectedProvince = v);
                      if (v != null) _loadMunicipalities(v);
                    },
                  ),
          ),
          _LabeledField(
            label: 'Municipality',
            child: municipalitiesLoading
                ? const _DropdownLoading()
                : _Dropdown<Municipality>(
                    value: selectedMunicipality,
                    hint: selectedProvince == null
                        ? 'Select a province first'
                        : 'Municipality',
                    items: municipalities,
                    onChanged: selectedProvince == null
                        ? null
                        : (v) {
                            setState(() => selectedMunicipality = v);
                            if (v != null) _loadBarangays(v);
                          },
                  ),
          ),
          _LabeledField(
            label: 'Barangay',
            child: barangaysLoading
                ? const _DropdownLoading()
                : _Dropdown<Barangay>(
                    value: selectedBarangay,
                    hint: selectedMunicipality == null
                        ? 'Select a municipality first'
                        : 'Barangay',
                    items: barangays,
                    onChanged: selectedMunicipality == null
                        ? null
                        : (v) => setState(() => selectedBarangay = v),
                  ),
          ),
          _LabeledField(
            label: 'Street',
            child: _TextInput(
              controller: streetCtrl,
              hint: 'Street',
              validator: _requiredValidator,
            ),
          ),
          _LabeledField(
            label: 'House number',
            child: _TextInput(
              controller: houseNumberCtrl,
              hint: 'House number',
              validator: _requiredValidator,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // STEP 5 — Verification (real image picker + upload)
  // ===================================================================
  Widget _step5() {
    return Form(
      key: _formKeys[4],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('Step 5: One last thing'),
          const SizedBox(height: 8),
          Text(
            'We need a valid government ID to verify your identity before your account is approved.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.hint, height: 1.4),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickId,
            child: DottedUploadBox(uploaded: idFile != null),
          ),
          if (idFile != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                idFile!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // VALIDATORS
  // -----------------------------------------------------------------
  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != passwordCtrl.text) return 'Passwords do not match';
    return null;
  }
}

/// -----------------------------------------------------------------------
/// REUSABLE WIDGETS
/// -----------------------------------------------------------------------

class _StepTitle extends StatelessWidget {
  final String title;
  const _StepTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.label,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.label,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;
  final bool obscureText;
  final Widget? suffixIcon;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      enabled: enabled,
      obscureText: obscureText,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.label),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.hint, fontSize: 15),
        filled: true,
        fillColor: enabled ? AppColors.inputFill : AppColors.inputFill.withAlpha(153),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?>? onChanged;

  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.hint),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
          hint: Text(hint, style: GoogleFonts.inter(color: AppColors.hint, fontSize: 15)),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.label),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(e.toString(), overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Shown in place of a dropdown while its options are being fetched
/// from the PSGC API.
class _DropdownLoading extends StatelessWidget {
  const _DropdownLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.hint),
            ),
          ),
          const SizedBox(width: 10),
          Text('Loading…', style: GoogleFonts.inter(color: AppColors.hint, fontSize: 14)),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final ValueChanged<DateTime> onPicked;

  const _DatePickerField({
    required this.value,
    required this.hint,
    required this.onPicked,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  String _format(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pickDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value == null ? hint : _format(value!),
              style: TextStyle(
                fontSize: 15,
                color: value == null ? AppColors.hint : AppColors.label,
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.hint),
          ],
        ),
      ),
    );
  }
}

class DottedUploadBox extends StatelessWidget {
  final bool uploaded;
  const DottedUploadBox({super.key, this.uploaded = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: uploaded ? AppColors.primary : AppColors.hint,
      ),
      child: Container(
        width: double.infinity,
        height: 160,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              uploaded ? Icons.check_circle : Icons.upload_rounded,
              size: 32,
              color: uploaded ? AppColors.primary : AppColors.hint,
            ),
            const SizedBox(height: 8),
            Text(
              uploaded ? 'ID selected — tap to change' : 'Upload ID',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: uploaded ? AppColors.primary : AppColors.hint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(14),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dashWidth = 6.0;
      const dashGap = 4.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashGap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// -----------------------------------------------------------------------
/// SIMPLE "PENDING APPROVAL" SCREEN (shown after submit)
/// -----------------------------------------------------------------------
class _PendingApprovalPage extends StatelessWidget {
  const _PendingApprovalPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Your application has been received.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                "We're reviewing your registration. You'll receive an email once a decision has been made.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.hint),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Back to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
