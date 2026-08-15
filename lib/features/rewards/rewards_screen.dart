import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import 'repositories/reward_repository.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  bool _isSyncing = false;
  int _unclaimedPoints = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUnclaimedAndSync(showToast: false);
    });
  }

  Future<void> _checkUnclaimedAndSync({bool showToast = true}) async {
    final userModel = ref.read(authProvider).userModel;
    final userId = userModel?.uid ?? '';
    if (userId.isEmpty) return;

    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {
      final repo = ref.read(rewardRepositoryProvider);

      if (showToast) {
        // Explicit claim action
        final claimed = await repo.syncAndAwardDeliveredOrders(userId);
        final remaining = await repo.getUnclaimedRewardPoints(userId);

        if (mounted) {
          setState(() {
            _unclaimedPoints = remaining;
            _isSyncing = false;
          });

          ScaffoldMessenger.of(context).clearSnackBars();
          if (claimed > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 Claimed $claimed reward points from your delivered orders!'),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('All reward points for your delivered orders are up to date!'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      } else {
        // Initial silent check
        final pending = await repo.getUnclaimedRewardPoints(userId);
        if (mounted) {
          setState(() {
            _unclaimedPoints = pending;
            _isSyncing = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pointsAsync = ref.watch(userRewardPointsStreamProvider);
    final historyAsync = ref.watch(userRewardHistoryStreamProvider);
    final hasPendingClaim = _unclaimedPoints > 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Rewards & Points',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Iconsax.refresh, size: 20),
            tooltip: 'Sync Rewards',
            onPressed: _isSyncing ? null : () => _checkUnclaimedAndSync(showToast: true),
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.textDark, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _checkUnclaimedAndSync(showToast: true),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Total Reward Points Hero Card ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'YOUR BALANCE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Iconsax.star1, color: Color(0xFFFFD700), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Perfect Rewards',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    pointsAsync.when(
                      data: (pts) => Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            '⭐ ',
                            style: TextStyle(fontSize: 28),
                          ),
                          Text(
                            '$pts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Points',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        ),
                      ),
                      error: (err, stack) => const Text(
                        '0 Points',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.info_circle, color: Colors.white70, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Points credited upon delivery of qualifying menu product orders.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 2. Dynamic Claim Banner ────────────────────────────────────
              InkWell(
                onTap: _isSyncing ? null : () => _checkUnclaimedAndSync(showToast: true),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: hasPendingClaim
                        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB))
                        : (isDark ? AppColors.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasPendingClaim
                          ? const Color(0xFFF59E0B)
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                      width: hasPendingClaim ? 1.5 : 1.0,
                    ),
                    boxShadow: hasPendingClaim
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasPendingClaim
                              ? const Color(0xFFFEF3C7)
                              : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade100),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasPendingClaim ? Iconsax.award5 : Iconsax.tick_circle,
                          color: hasPendingClaim
                              ? const Color(0xFFD97706)
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasPendingClaim
                                  ? 'Claim Your Reward Points! 🎉'
                                  : 'All Rewards Claimed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: hasPendingClaim
                                    ? (isDark ? Colors.white : const Color(0xFF92400E))
                                    : (isDark ? Colors.grey.shade300 : AppColors.textDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasPendingClaim
                                  ? 'You have $_unclaimedPoints points ready to claim from delivered orders'
                                  : 'Place a new qualifying menu order to earn more points!',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: hasPendingClaim
                                    ? (isDark ? Colors.amber.shade200 : const Color(0xFFB45309))
                                    : (isDark ? Colors.grey.shade500 : AppColors.textLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: hasPendingClaim ? AppColors.primaryGradient : null,
                          color: hasPendingClaim
                              ? null
                              : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: hasPendingClaim
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: _isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                hasPendingClaim
                                    ? 'Claim $_unclaimedPoints Pts'
                                    : 'All Claimed ✓',
                                style: TextStyle(
                                  color: hasPendingClaim
                                      ? Colors.white
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── 3. Reward History Header ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reward History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    'Delivered Orders',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 4. Transaction List ────────────────────────────────────────
              historyAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Iconsax.award5,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Claimed Rewards Yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order menu items above the minimum branch threshold. Points are credited once delivered!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      final formattedDate =
                          DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Iconsax.award5,
                                  color: Color(0xFFD97706),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '+${tx.points} Points Earned',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Order #${tx.orderNumber} • ${tx.branchName}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${tx.points} pts',
                                style: const TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, stack) => Text(
                  'Failed to load reward history',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
