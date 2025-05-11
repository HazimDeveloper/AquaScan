
// lib/widgets/user/report_card.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/theme.dart';
import '../../models/report_model.dart';

class ReportCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback? onTap;
  
  const ReportCard({
    Key? key,
    required this.report,
    this.onTap,
  }) : super(key: key);

  String _getWaterQualityText() {
    switch (report.waterQuality) {
      case WaterQualityState.clean:
        return 'Clean';
      case WaterQualityState.slightlyContaminated:
        return 'Slightly Contaminated';
      case WaterQualityState.moderatelyContaminated:
        return 'Moderately Contaminated';
      case WaterQualityState.heavilyContaminated:
        return 'Heavily Contaminated';
      case WaterQualityState.unknown:
      default:
        return 'Unknown';
    }
  }
  
  Color _getWaterQualityColor() {
    switch (report.waterQuality) {
      case WaterQualityState.clean:
        return Colors.blue;
      case WaterQualityState.slightlyContaminated:
        return Colors.green;
      case WaterQualityState.moderatelyContaminated:
        return Colors.orange;
      case WaterQualityState.heavilyContaminated:
        return Colors.red;
      case WaterQualityState.unknown:
      default:
        return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section (if available)
            if (report.imageUrls.isNotEmpty)
              SizedBox(
                height: 150,
                width: double.infinity,
                child: PageView.builder(
                  itemCount: report.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      report.imageUrls[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            
            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: report.isResolved
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          report.isResolved ? 'Resolved' : 'Pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getWaterQualityColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getWaterQualityColor(),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.water_drop,
                              color: _getWaterQualityColor(),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getWaterQualityText(),
                              style: TextStyle(
                                color: _getWaterQualityColor(),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Title
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    report.description,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Location and time
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          report.address,
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeago.format(report.createdAt),
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}