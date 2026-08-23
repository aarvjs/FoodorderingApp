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
  int _unclaimedPoints = 0;
  bool _isSyncing = false;
  double _pointValue = 0.25;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfigAndSync();
    });
  }

  Future<void> _loadConfigAndSync() async {
    final userModel = ref.read(authProvider).userModel;
    final userId = userModel?.uid ?? '';
    if (userId.isEmpty) return;

    try {
      final repo = ref.read(rewardRepositoryProvider);
      final config = await repo.getRewardConfigByBranch('ALL', '');
      if (config != null) {
        setState(() {
          _pointValue = config.pointValue;
        });
      }
    } catch (_) {}

    await _checkUnclaimedAndSync(showToast: false);
  }

  Future<void> _checkUnclaimedAndSync({bool showToast = false}) async {
    final userModel = ref.read(authProvider).userModel;
    final userId = userModel?.uid ?? '';
    if (userId.isEmpty) return;

    setState(() {
      if (showToast) _isSyncing = true;
    });


    final repo = ref.read(rewardRepositoryProvider);

    try {
      if (showToast) {
        final awardedCount = await repo.syncAndAwardDeliveredOrders(userId);
        if (mounted) {
          if (awardedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 Claimed $awardedCount reward points from delivered orders!'),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All delivered order rewards are up to date!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      final unclaimed = await repo.getUnclaimedRewardPoints(userId);
      if (mounted) {
        setState(() {
          _unclaimedPoints = unclaimed;
        });
      }
    } catch (e) {
      debugPrint('[RewardsScreen] Error checking unclaimed points: $e');
    } finally {
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
      appBar: AppBar(
        title: const Text(
          'Reward Wallet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
            ),
            tooltip: 'Sync Rewards',
            onPressed: _isSyncing ? null : () => _checkUnclaimedAndSync(showToast: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                          'YOUR REWARD WALLET',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Iconsax.star1, color: Color(0xFFFFD700), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Member Benefits',
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
                      data: (pts) {
                        final rupeeValue = pts * _pointValue;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                            const SizedBox(height: 4),
                            Text(
                              'Equivalent Cash Value: ₹${rupeeValue.toStringAsFixed(2)} (1 Pt = ₹${_pointValue.toStringAsFixed(2)})',
                              style: const TextStyle(
                                color: Color(0xFFFFE082),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
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
                    const SizedBox(height: 16),
                    Container(
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
                              'Points credited automatically when orders reach Delivered status.',
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
                    'Reward Ledger & History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    'All Transactions',
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
                            'No Reward Activity Yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order menu items above minimum branch slab thresholds. Points will credit after order delivery!',
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
                      final type = (tx.type.isNotEmpty ? tx.type : (tx.points >= 0 ? 'EARNED' : 'REDEEMED')).toUpperCase();
                      final isEarned = type == 'EARNED';
                      final isRefund = type == 'REFUNDED';

                      Color badgeBg = const Color(0xFFDCFCE7);
                      Color badgeText = const Color(0xFF15803D);
                      IconData iconData = Iconsax.award5;
                      Color iconColor = const Color(0xFFD97706);

                      if (!isEarned && !isRefund) {
                        badgeBg = const Color(0xFFFFEDD5);
                        badgeText = const Color(0xFFC2410C);
                        iconData = Iconsax.ticket_discount;
                        iconColor = const Color(0xFFEA580C);
                      } else if (isRefund) {
                        badgeBg = const Color(0xFFDBEAFE);
                        badgeText = const Color(0xFF1D4ED8);
                        iconData = Iconsax.refresh_circle;
                        iconColor = const Color(0xFF2563EB);
                      }

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
                                color: badgeBg.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  iconData,
                                  color: iconColor,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.description.isNotEmpty
                                        ? tx.description
                                        : (isEarned
                                            ? '+${tx.points} Points Earned'
                                            : '${tx.points} Points Redeemed'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Order #${tx.orderNumber.isNotEmpty ? tx.orderNumber : tx.orderId} • ${tx.branchName.isNotEmpty ? tx.branchName : "Restaurant"}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : AppColors.textLight,
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tx.points > 0 ? '+${tx.points} pts' : '${tx.points} pts',
                                style: TextStyle(
                                  color: badgeText,
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
