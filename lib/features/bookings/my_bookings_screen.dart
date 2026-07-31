import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../home/providers/restaurant_providers.dart';
import '../../models/table_model.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookingsAsync = ref.watch(customerBookingsStreamProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings 🪑', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: isDark ? AppColors.darkPrimary : AppColors.primary,
            labelColor: isDark ? AppColors.darkPrimary : AppColors.primary,
            unselectedLabelColor: isDark ? Colors.grey.shade500 : AppColors.textLight,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: SafeArea(
          child: bookingsAsync.when(
            data: (bookings) {
              final upcoming = bookings.where((b) => b.status == 'CONFIRMED' || b.status == 'ACCEPTED' || b.status == 'PENDING').toList();
              final completed = bookings.where((b) => b.status == 'COMPLETED').toList();
              final cancelled = bookings.where((b) => b.status == 'CANCELLED' || b.status == 'REJECTED' || b.status == 'NO_SHOW').toList();

              return TabBarView(
                children: [
                  upcoming.isEmpty
                      ? _buildEmptyState(context, 'No Upcoming Reservations', 'Book a dining table at your favorite restaurant branch.')
                      : _buildBookingsList(upcoming, isDark),
                  completed.isEmpty
                      ? _buildEmptyState(context, 'No Completed Bookings', 'You haven\'t completed any table reservations yet.')
                      : _buildBookingsList(completed, isDark),
                  cancelled.isEmpty
                      ? _buildEmptyState(context, 'No Cancelled Bookings', 'No cancelled table reservations.')
                      : _buildBookingsList(cancelled, isDark),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading bookings: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String desc) {
    return EmptyState(
      title: title,
      description: desc,
      fallbackIcon: Iconsax.calendar_remove,
    );
  }

  Widget _buildBookingsList(List<TableBookingModel> bookings, bool isDark) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final isConfirmed = booking.status == 'CONFIRMED' || booking.status == 'ACCEPTED';
        final isPending = booking.status == 'PENDING';
        final isCompleted = booking.status == 'COMPLETED';

        Color badgeBg = Colors.red.withOpacity(0.15);
        Color badgeText = Colors.red;
        if (isConfirmed) {
          badgeBg = AppColors.success.withOpacity(0.15);
          badgeText = AppColors.success;
        } else if (isPending) {
          badgeBg = Colors.amber.withOpacity(0.15);
          badgeText = Colors.amber.shade900;
        } else if (isCompleted) {
          badgeBg = Colors.blue.withOpacity(0.15);
          badgeText = Colors.blue;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking.restaurantName.isNotEmpty ? booking.restaurantName : 'Restaurant Reservation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                      ),
                    ),
                  ),
                ],
              ),
              if (booking.branchName.isNotEmpty) ...[
                const Gap(2),
                Text(
                  'Branch: ${booking.branchName}',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : AppColors.textLight),
                ),
              ],
              const Gap(12),
              const Divider(),
              const Gap(8),
              Row(
                children: [
                  const Icon(Icons.table_restaurant_rounded, size: 16, color: AppColors.primary),
                  const Gap(6),
                  Text('Table: ${booking.tableNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  const Icon(Icons.people_alt_rounded, size: 16, color: AppColors.primary),
                  const Gap(6),
                  Text('${booking.guests} Guests', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const Gap(8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
                  const Gap(6),
                  Text(booking.date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                  const Gap(6),
                  Text(booking.time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              if (booking.specialRequest != null && booking.specialRequest!.isNotEmpty) ...[
                const Gap(8),
                Text(
                  'Note: ${booking.specialRequest}',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
