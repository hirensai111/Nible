// lib/widgets/delivery_card.dart
import 'package:flutter/material.dart';
import 'package:nible/models/user.dart';
import '../constants/colors.dart';
import '../models/delivery.dart';

class DeliveryCard extends StatelessWidget {
  final DeliveryModel delivery;

  const DeliveryCard({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: Row(
        children: [
          // Orange vertical bar indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.hokieOrange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Delivery details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location
                Text(
                  "${delivery.pickupLocation} to ${delivery.dropoffLocation}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),

                // Details
                Text(
                  "${delivery.itemCount} ${delivery.itemCount == 1 ? 'item' : 'items'} • ${delivery.distance} miles • ${delivery.estimatedTime} min",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),

          // Fee amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.hokieOrange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "\$${delivery.fee.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
