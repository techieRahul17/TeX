import 'package:flutter/material.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/config/wallpapers.dart';

class WallpaperSelector extends StatelessWidget {
  final Function(WallpaperOption) onSelect;
  final String? currentWallpaperId;

  const WallpaperSelector({
    super.key,
    required this.onSelect,
    this.currentWallpaperId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      // Glassmorphism background for the sheet
      decoration: BoxDecoration(
        color: StellarTheme.cardColor.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: StellarTheme.textSecondary.withOpacity(0.1),
            width: 1,
          )
        ),
         boxShadow: [
            BoxShadow(
              color: StellarTheme.primaryNeon.withOpacity(0.2),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, -10),
            )
          ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Choose Wallpaper',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: Wallpapers.options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (context, index) {
                final option = Wallpapers.options[index];
                final isSelected = currentWallpaperId == option.id;

                return GestureDetector(
                  onTap: () => onSelect(option),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: option.colors,
                              begin: option.begin,
                              end: option.end,
                              stops: option.stops,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: StellarTheme.primaryNeon, width: 3)
                                : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: StellarTheme.primaryNeon.withOpacity(0.4),
                                      blurRadius: 12,
                                    )
                                  ]
                                : [],
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.name,
                        style: TextStyle(
                          color: isSelected ? StellarTheme.primaryNeon : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
