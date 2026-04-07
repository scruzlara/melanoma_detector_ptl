import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/antigravity_decision_service.dart';
import '../../theme/app_theme.dart';

/// Écran de sélection de zone pour explorer les arbres de décision
class PageAntigravityZone extends StatelessWidget {
  const PageAntigravityZone({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Arbres de décision',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.primaryGradient : AppTheme.lightGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_tree,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Algorithme de reconstruction',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sélectionnez une zone pour explorer les techniques',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.1),

                const SizedBox(height: 24),

                // Zone cards
                ...ReconstructionZone.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final zone = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildZoneCard(context, zone, isDark, index),
                  );
                }),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoneCard(
    BuildContext context,
    ReconstructionZone zone,
    bool isDark,
    int index,
  ) {
    final service = AntigravityDecisionService();
    final tree = service.getDecisionTree(zone);

    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PageAntigravityTreeView(zone: zone),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient:
                    isDark ? AppTheme.cardGradient : AppTheme.lightCardGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentCyan.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        zone.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.displayName,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tree.subRegions.length} sous-régions',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index))
        .slideX(begin: index.isEven ? -0.1 : 0.1);
  }
}

/// Écran de visualisation de l'arbre de décision d'une zone
class PageAntigravityTreeView extends StatefulWidget {
  final ReconstructionZone zone;

  const PageAntigravityTreeView({super.key, required this.zone});

  @override
  State<PageAntigravityTreeView> createState() =>
      _PageAntigravityTreeViewState();
}

class _PageAntigravityTreeViewState extends State<PageAntigravityTreeView> {
  late ZoneDecisionTree _tree;
  int _selectedSubRegionIndex = 0;
  double _testSizeMm = 15.0; // Taille test par défaut (1.5 cm)

  @override
  void initState() {
    super.initState();
    _tree = AntigravityDecisionService().getDecisionTree(widget.zone);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subRegion = _tree.subRegions[_selectedSubRegionIndex];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.zone.emoji} ${widget.zone.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.primaryGradient : AppTheme.lightGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Slider de taille
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Taille de test',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          Text(
                            '${_testSizeMm.toStringAsFixed(0)} mm '
                            '(${(_testSizeMm / 10).toStringAsFixed(1)} cm)',
                            style: const TextStyle(
                              color: AppTheme.accentCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _testSizeMm,
                        min: 1,
                        max: 60,
                        divisions: 59,
                        activeColor: AppTheme.accentCyan,
                        onChanged: (v) => setState(() => _testSizeMm = v),
                      ),
                    ],
                  ),
                ),
              ),

              // Sub-region tabs
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _tree.subRegions.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedSubRegionIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(_tree.subRegions[index].name),
                        selected: isSelected,
                        onSelected:
                            (_) =>
                                setState(() => _selectedSubRegionIndex = index),
                        selectedColor: AppTheme.accentCyan.withValues(
                          alpha: 0.3,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color:
                              isSelected
                                  ? AppTheme.accentCyan
                                  : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Branches
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...subRegion.branches.asMap().entries.map((entry) {
                        final branch = entry.value;
                        final matches = branch.matchesSize(_testSizeMm);
                        return _buildBranchCard(
                          context,
                          branch,
                          matches,
                          isDark,
                          entry.key,
                        );
                      }),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchCard(
    BuildContext context,
    DecisionBranch branch,
    bool matches,
    bool isDark,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradient : AppTheme.lightCardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              matches
                  ? AppTheme.accentCyan.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
          width: matches ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:
                  matches
                      ? AppTheme.accentCyan.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  matches ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color:
                      matches
                          ? AppTheme.accentCyan
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black26),
                ),
                const SizedBox(width: 8),
                Text(
                  branch.criteria.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        matches
                            ? AppTheme.accentCyan
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black45),
                  ),
                ),
                if (matches) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '✓ Correspond',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Techniques
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  branch.techniques.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            matches
                                ? AppTheme.accentCyan.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              matches
                                  ? AppTheme.accentCyan.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              matches
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : Colors.black38),
                          fontWeight:
                              matches ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 80 * index));
  }
}
