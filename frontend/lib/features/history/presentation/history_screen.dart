import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _historyItems = [
    {'title': 'Water plants', 'time': '8:43 AM', 'category': 'Quick Task', 'when': 'Today'},
    {'title': 'Buy milk', 'time': '7:15 AM', 'category': 'Quick Task', 'when': 'Today'},
    {'title': 'Study networking principles', 'time': '4:20 PM', 'category': 'Focus Task', 'when': 'Yesterday'},
    {'title': 'Feed dog', 'time': '8:00 AM', 'category': 'Quick Task', 'when': 'Yesterday'},
    {'title': 'Finish Chapter 5 reading', 'time': 'Monday', 'category': 'Focus Task', 'when': 'This Week'},
    {'title': 'Reply to landlord', 'time': 'Sunday', 'category': 'Quick Task', 'when': 'This Week'},
  ];

  @override
  Widget build(BuildContext context) {
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    
    final primaryTextColor = isThemeDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondaryTextColor = isThemeDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final fieldColor = isThemeDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6);

    final filteredHistory = _historyItems.where((item) {
      final title = item['title'].toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();

    final Map<String, List<Map<String, dynamic>>> groupedHistory = {};
    for (var item in filteredHistory) {
      final key = item['when'];
      groupedHistory[key] ??= [];
      groupedHistory[key]!.add(item);
    }

    final groups = ['Today', 'Yesterday', 'This Week', 'Older'];

    return Scaffold(
      backgroundColor: isThemeDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'History.',
                style: GoogleFonts.inter(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              
              // Clean borderless Search Input
              Container(
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 16, color: primaryTextColor),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search timeline...',
                    hintStyle: GoogleFonts.inter(color: secondaryTextColor.withOpacity(0.5)),
                    prefixIcon: Icon(LucideIcons.search, size: 18, color: secondaryTextColor.withOpacity(0.5)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: filteredHistory.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final itemsInGroup = groupedHistory[group];
                          
                          if (itemsInGroup == null || itemsInGroup.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Text(
                                  group.toLowerCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: secondaryTextColor.withOpacity(0.5),
                                  ),
                                ),
                              ),
                              ...itemsInGroup.map((item) => _buildHistoryItem(item, secondaryTextColor)),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, Color secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checked state indicator - subtle, grey
          Icon(
            LucideIcons.check,
            size: 16,
            color: secondaryTextColor.withOpacity(0.4),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item['title'],
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.lineThrough,
                color: secondaryTextColor.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item['time'],
            style: GoogleFonts.inter(
              fontSize: 13,
              color: secondaryTextColor.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.archive, size: 36, color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'Nothing found in history.',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
