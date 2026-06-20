import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/premium_theme.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/premium_card.dart';
import 'result_screen_premium.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isServerHealthy = false;
  String? _errorMessage;
  DateTime? _lastServerCheck;
  Timer? _healthTimer;

  final List<_TemplatePreset> _templates = const [
    _TemplatePreset(
      title: 'Quality Compounders',
      subtitle: 'Strong profitability with controlled leverage',
      query: 'Show stocks with ROE above 15 and debt to equity below 0.5',
      icon: Icons.shield_rounded,
      tone: Color(0xFFDBEAFE),
    ),
    _TemplatePreset(
      title: 'Reasonable Valuation',
      subtitle: 'Earnings-backed valuations in large businesses',
      query: 'Show stocks with PE below 20 and market cap above 1000',
      icon: Icons.balance_rounded,
      tone: Color(0xFFE0F2FE),
    ),
    _TemplatePreset(
      title: 'Growth Watch',
      subtitle: 'Revenue momentum with healthy balance sheets',
      query:
          'Show stocks with revenue growth above 20 and debt to equity below 1',
      icon: Icons.trending_up_rounded,
      tone: Color(0xFFDCFCE7),
    ),
    _TemplatePreset(
      title: 'Defensive Filter',
      subtitle: 'Conservative profile with tighter risk controls',
      query:
          'Show stocks with PE below 25 and debt to equity below 0.3 and market cap above 5000',
      icon: Icons.security_rounded,
      tone: Color(0xFFFFEDD5),
    ),
  ];

  final List<String> _quickPrompts = const [
    'IT stocks with PE below 25',
    'Banking stocks with ROE above 15',
    'Low debt pharma stocks',
    'Large cap growth stocks',
    'Dividend stocks with low volatility',
  ];

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    _checkServerHealth();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _checkServerHealth(silent: true),
    );
  }

  void _onQueryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkServerHealth({bool silent = false}) async {
    bool isHealthy = false;

    try {
      isHealthy = await ApiService().checkHealth();
    } catch (_) {
      isHealthy = false;
    }

    if (!mounted) return;

    setState(() {
      _isServerHealthy = isHealthy;
      _lastServerCheck = DateTime.now();
      if (!isHealthy && !silent) {
        _errorMessage = 'Backend is offline. ${ApiConfig.physicalDeviceHint}';
      } else if (_errorMessage?.contains('Backend is offline') == true) {
        _errorMessage = null;
      }
    });
  }

  Future<void> _runScreener({String? predefinedQuery}) async {
    final query = predefinedQuery ?? _queryController.text.trim();

    if (query.isEmpty) {
      setState(() => _errorMessage = 'Enter a screening query to continue.');
      return;
    }

    if (!_isServerHealthy) {
      setState(
        () =>
            _errorMessage = 'Backend is offline. Refresh health and try again.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await ApiService().fetchStocks(query);
      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _errorMessage = 'No matches found for this query.';
          _isLoading = false;
        });
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(results: results, query: query),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _fillQuery(String query, {bool focusField = false}) {
    _queryController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );

    setState(() => _errorMessage = null);

    if (focusField) {
      _queryFocusNode.requestFocus();
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final hasQuery = _queryController.text.trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Dynamic mesh background circle glow (Top Left)
          Positioned(
            left: -80,
            top: -95,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [const Color(0x2210B981), const Color(0x0010B981)]
                      : [const Color(0x406366F1), const Color(0x006366F1)],
                ),
              ),
            ),
          ),
          // Dynamic mesh background circle glow (Bottom Right)
          Positioned(
            right: -90,
            bottom: -120,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [const Color(0x1F6366F1), const Color(0x006366F1)]
                      : [const Color(0x2B3B82F6), const Color(0x003B82F6)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => _checkServerHealth(),
              color: isDark ? const Color(0xFF10B981) : const Color(0xFF6366F1),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 14),
                  _buildWorkspaceCard(hasQuery: hasQuery),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    _buildErrorBanner(),
                  ],
                  const SizedBox(height: 16),
                  _buildQuickPromptsCard(),
                  const SizedBox(height: 16),
                  _buildTemplateSection(),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Pull down to refresh backend health and telemetry.',
                      style: PremiumTypography.caption.copyWith(
                        color: isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBg = _isServerHealthy
        ? (isDark ? const Color(0x2210B981) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0x22F43F5E) : const Color(0xFFFFF1F2));
    final statusText = _isServerHealthy
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
        : (isDark ? const Color(0xFFFB7185) : const Color(0xFFB91C1C));

    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;
        final name = auth.isAuthenticated ? (auth.currentUser?.name ?? 'Investor') : 'Guest';

        return Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF3B82F6)],
                  ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.transparent,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0xFF4F46E5).withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155).withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      auth.currentUser?.avatarLabel ?? 'EQ',
                      style: PremiumTypography.body1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $name',
                          style: PremiumTypography.h2.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'AI Screener Command Center',
                          style: PremiumTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: () async {
                      if (auth.isAuthenticated) {
                        await AuthService.instance.logout();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Logged out successfully.'),
                          ),
                        );
                        return;
                      }

                      final loggedIn = await showAuthSheet(context);
                      if (!mounted || !loggedIn) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Welcome, ${AuthService.instance.currentUser?.name ?? 'Investor'}',
                          ),
                          backgroundColor: PremiumColors.profit,
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: isDark
                          ? const Color(0xFF475569).withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      auth.isAuthenticated
                          ? Icons.logout_rounded
                          : Icons.login_rounded,
                      size: 16,
                    ),
                    label: Text(
                      auth.isAuthenticated ? 'Logout' : 'Login',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusPill(
                      icon: _isServerHealthy
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      text: _isServerHealthy ? 'Server Online' : 'Server Offline',
                      background: statusBg,
                      textColor: statusText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _checkServerHealth(),
                      child: _buildStatusPill(
                        icon: Icons.refresh_rounded,
                        text: _lastServerCheck == null
                            ? 'Checking...'
                            : 'Updated ${_formatTime(_lastServerCheck!)}',
                        background: isDark
                            ? const Color(0xFF334155).withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.2),
                        textColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String text,
    required Color background,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PremiumTypography.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceCard({required bool hasQuery}) {
    final canSubmit = !_isLoading && _isServerHealthy && hasQuery;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PremiumCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: isDark ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Screener Workspace',
                style: PremiumTypography.h3.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : PremiumColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Describe your trading strategy below to filter equities instantly.',
            style: PremiumTypography.caption.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _queryController,
            focusNode: _queryFocusNode,
            minLines: 2,
            maxLines: 3,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runScreener(),
            style: TextStyle(
              color: isDark ? Colors.white : PremiumColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Show finance stocks with PE below 20 and ROE above 15',
              alignLabelWithHint: true,
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? const Color(0xFF10B981) : const Color(0xFF6366F1),
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      onPressed: () => _fillQuery(''),
                      icon: Icon(
                        Icons.clear_rounded,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    )
                  : null,
              fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                  width: 2,
                ),
              ),
              hintStyle: TextStyle(
                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: hasQuery ? () => _fillQuery('') : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: canSubmit
                        ? (isDark ? PremiumColors.profitGradient : PremiumColors.primaryGradient)
                        : null,
                    color: !canSubmit
                        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: canSubmit
                        ? [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: canSubmit ? () => _runScreener() : null,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                    label: Text(
                      _isLoading ? 'Running...' : 'Run Screener',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'Quick Prompts',
            style: PremiumTypography.h3.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : PremiumColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _quickPrompts.length,
            itemBuilder: (context, index) {
              final prompt = _quickPrompts[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 4 : 0,
                  right: 10,
                ),
                child: _buildPromptChip(prompt),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPromptChip(String prompt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading
            ? null
            : () => _fillQuery('Show $prompt', focusField: true),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.5)
                  : const Color(0xFF93C5FD).withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black12 : const Color(0x06000000),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_rounded,
                size: 15,
                color: isDark ? const Color(0xFF10B981) : const Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Text(
                prompt,
                style: PremiumTypography.caption.copyWith(
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Curated Presets',
            style: PremiumTypography.h3.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : PremiumColors.textPrimary,
            ),
          ),
        ),
        ..._templates.map(_buildTemplateTile),
      ],
    );
  }

  Widget _buildTemplateTile(_TemplatePreset template) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? const Color(0xFF10B981) : const Color(0xFF6366F1);
    final toneColor = isDark
        ? const Color(0xFF1F2937)
        : template.tone.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: _isLoading
            ? null
            : () => _fillQuery(template.query, focusField: true),
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: toneColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(template.icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: PremiumTypography.body1.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : PremiumColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTypography.caption.copyWith(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: _isServerHealthy && !_isLoading
                    ? (isDark ? PremiumColors.profitGradient : PremiumColors.primaryGradient)
                    : null,
                color: (!_isServerHealthy || _isLoading)
                    ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: _isLoading || !_isServerHealthy
                    ? null
                    : () => _runScreener(predefinedQuery: template.query),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Run',
                  style: PremiumTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerBg = isDark ? const Color(0xFF31151A) : const Color(0xFFFFF1F2);
    final borderBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA);
    final textCol = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderBg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: isDark ? const Color(0xFFFB7185) : PremiumColors.loss,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: PremiumTypography.caption.copyWith(
                color: textCol,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _checkServerHealth(),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _TemplatePreset {
  final String title;
  final String subtitle;
  final String query;
  final IconData icon;
  final Color tone;

  const _TemplatePreset({
    required this.title,
    required this.subtitle,
    required this.query,
    required this.icon,
    required this.tone,
  });
}
