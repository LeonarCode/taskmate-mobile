import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/image_utils.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../models/rating_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_tab_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_client.dart';
import '../../services/server_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<RatingModel> _ratings = [];
  bool _ratingsLoading = true;
  String? _ratingsError;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    try {
      final ratings = await context.read<ServerService>().received(limit: 5);
      if (!mounted) return;
      setState(() {
        _ratings = ratings;
        _ratingsError = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _ratingsError = e.message);
    } finally {
      if (mounted) setState(() => _ratingsLoading = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<AuthProvider>().refreshUser(),
      _loadRatings(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    if (user == null) return const BrandSpinner();

    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      body: RefreshIndicator(
        color: AppColors.purple600,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(context, isDark, user, auth),
            SliverToBoxAdapter(child: _buildBody(context, isDark, user, auth)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext ctx,
    bool isDark,
    UserModel user,
    AuthProvider auth,
  ) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: isDark ? AppColors.dark800 : Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [AppColors.dark800, AppColors.dark700],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [AppColors.purple600, AppColors.pink500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    UserAvatar(
                      name: user.fullName,
                      userId: user.id,
                      photoUrl: user.photoUrl,
                      radius: 50,
                      backgroundColor: Colors.white.withAlpha(40),
                      textColor: Colors.white,
                    ),
                    GestureDetector(
                      onTap: () => _changePhoto(ctx, auth),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: AppColors.purple600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(180),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RatingBarIndicator(
                      rating: user.averageRating,
                      itemBuilder: (_, _) => const Icon(
                        Icons.star_rounded,
                        color: AppColors.amber400,
                      ),
                      itemCount: 5,
                      itemSize: 20,
                      unratedColor: Colors.white.withAlpha(80),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${user.averageRating.toStringAsFixed(1)} (${user.ratingCount})',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(200),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: isDark ? Colors.white : AppColors.gray700,
          ),
          onPressed: () => ctx.read<ThemeProvider>().toggleTheme(),
        ),
        IconButton(
          icon: Icon(
            Icons.logout_rounded,
            color: isDark ? Colors.white : AppColors.gray700,
          ),
          onPressed: () => _confirmSignOut(ctx, auth),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    bool isDark,
    UserModel user,
    AuthProvider auth,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Profile Info', isDark),
          const SizedBox(height: 10),
          _infoCard(isDark, [
            _InfoRow(
              icon: Icons.person_rounded,
              label: 'Full Name',
              value: user.fullName,
              color: AppColors.purple600,
            ),
            _InfoRow(
              icon: Icons.alternate_email_rounded,
              label: 'Username',
              value: '@${user.username}',
              color: AppColors.pink500,
            ),
            _InfoRow(
              icon: Icons.cake_rounded,
              label: 'Age',
              value: '${user.age} years old',
              color: AppColors.amber500,
            ),
            _InfoRow(
              icon: user.userType == UserType.student
                  ? Icons.school_rounded
                  : Icons.work_rounded,
              label: 'Type',
              value: user.userType == UserType.student
                  ? '🎓 Student'
                  : '💼 Employee',
              color: AppColors.green500,
            ),
            if (user.organization != null)
              _InfoRow(
                icon: Icons.apartment_rounded,
                label: user.userType == UserType.student
                    ? 'University'
                    : 'Company',
                value: user.organization!,
                color: AppColors.pink400,
              ),
            _InfoRow(
              icon: Icons.mail_rounded,
              label: 'Email',
              value: user.email,
              color: AppColors.purple400,
            ),
          ]),
          const SizedBox(height: 24),

          _sectionTitle('Ratings & Feedback', isDark),
          const SizedBox(height: 10),
          _buildRatings(isDark),
          const SizedBox(height: 24),

          GradientButton(
            label: 'Edit Profile',
            icon: Icons.edit_rounded,
            onTap: () => _showEditProfile(ctx, user, auth),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRatings(bool isDark) {
    if (_ratingsLoading) {
      return const Padding(padding: EdgeInsets.all(24), child: BrandSpinner());
    }
    if (_ratingsError != null && _ratings.isEmpty) {
      return _emptySection(_ratingsError!, Icons.cloud_off_rounded, isDark);
    }
    if (_ratings.isEmpty) {
      return _emptySection('No ratings yet', Icons.star_border_rounded, isDark);
    }
    return Column(
      children: [
        for (final r in _ratings) _RatingTile(rating: r, isDark: isDark),
      ],
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : AppColors.gray900,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _infoCard(bool isDark, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: AppColors.dark600, width: 1) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          final row = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: row.color.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(row.icon, color: row.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.gray500
                                  : AppColors.gray400,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            row.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.gray800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: isDark ? AppColors.dark600 : AppColors.gray100,
                  indent: 64,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _emptySection(String msg, IconData icon, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: AppColors.dark600, width: 1) : null,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: isDark ? AppColors.gray600 : AppColors.gray300,
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.gray500 : AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePhoto(BuildContext ctx, AuthProvider auth) async {
    final users = ctx.read<UserService>();
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Phones shrink the picture natively before it gets here (faster than
      // doing it in Dart); compressPhoto then trims it to the final size.
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (xFile == null || !ctx.mounted) return;

    showInfoSnack(ctx, 'Uploading photo...');
    try {
      final jpeg = await compressPhoto(await xFile.readAsBytes());
      // The backend stores it on Cloudinary and returns the https URL.
      await auth.updateUser(await users.uploadPhoto(jpeg));
      if (ctx.mounted) showInfoSnack(ctx, 'Profile photo updated!');
    } catch (e) {
      if (ctx.mounted) showErrorSnack(ctx, e);
    }
  }

  void _confirmSignOut(BuildContext ctx, AuthProvider auth) {
    showDialog<void>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ctx.read<HomeTabProvider>().reset();
              auth.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext ctx, UserModel user, AuthProvider auth) {
    showAppSheet<void>(ctx, (_) => _EditProfileSheet(user: user));
  }
}

// ── Edit Profile sheet ─────────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final UserModel user;

  const _EditProfileSheet({required this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _nameCtrl = TextEditingController(text: widget.user.fullName);
  late final _ageCtrl = TextEditingController(text: '${widget.user.age}');
  late final _orgCtrl = TextEditingController(
    text: widget.user.organization ?? '',
  );
  late UserType _userType = widget.user.userType;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _orgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }
    if (age == null || age < 1 || age > 120) {
      setState(() => _error = 'Enter an age from 1 to 120');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final users = context.read<UserService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await users.updateProfile(
        fullName: name,
        age: age,
        userType: _userType,
        // An empty value removes the organization.
        organization: _orgCtrl.text.trim(),
      );
      await auth.updateUser(updated);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SheetContainer(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.gray900,
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(
                  Icons.badge_rounded,
                  color: AppColors.purple600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                prefixIcon: Icon(Icons.cake_rounded, color: AppColors.amber500),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _orgCtrl,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'University or Company (Optional)',
                counterText: '',
                prefixIcon: Icon(
                  Icons.apartment_rounded,
                  color: AppColors.pink400,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'User Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.gray200 : AppColors.gray700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _typeOption('🎓 Student', UserType.student, isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _typeOption('💼 Employee', UserType.employee, isDark),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: _isLoading ? 'Saving...' : 'Save Changes',
              icon: Icons.save_rounded,
              onTap: _isLoading ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeOption(String label, UserType type, bool isDark) {
    final selected = _userType == type;
    return GestureDetector(
      onTap: () => setState(() => _userType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected
              ? null
              : (isDark ? AppColors.dark700 : AppColors.gray50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.purple600
                : (isDark ? AppColors.dark500 : AppColors.gray200),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : (isDark ? AppColors.gray400 : AppColors.gray600),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Supporting classes
// ─────────────────────────────────────────────

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _RatingTile extends StatelessWidget {
  final RatingModel rating;
  final bool isDark;

  const _RatingTile({required this.rating, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final comment = rating.comment;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: AppColors.dark600, width: 1) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rating.rater.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.gray900,
                  ),
                ),
              ),
              RatingBarIndicator(
                rating: rating.score,
                itemBuilder: (_, _) =>
                    const Icon(Icons.star_rounded, color: AppColors.amber400),
                itemCount: 5,
                itemSize: 16,
                unratedColor: isDark ? AppColors.dark500 : AppColors.gray200,
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"$comment"',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? AppColors.gray400 : AppColors.gray500,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'From ${rating.serverName} · ${DateFormat.yMMMd().format(rating.createdAt)}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.purple600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
