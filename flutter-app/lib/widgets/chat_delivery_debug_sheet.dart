import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../core/feedback/app_feedback.dart';
import '../providers/chat_provider.dart';
import '../services/chat_delivery_stats_service.dart';
import 'app_toast.dart';

enum _DeliveryTimelineFilter { all, failures, retries, images }

enum _DeliveryEventLevelFilter { all, recovered, blocked, reselect }

enum _DeliveryTimelineSortMode { latest, anomaliesFirst }

enum _DeliveryTimelineViewMode { full, recentAnomalies }

enum _DeliveryTimelineActionPriority { needsAction, monitoring, resolved }

class _DeliveryTimelineGroup {
  const _DeliveryTimelineGroup({
    required this.familyLabel,
    required this.summaryLabel,
    required this.latestStatusLabel,
    required this.recommendedActionLabel,
    required this.actionPriority,
    required this.actionPriorityLabel,
    required this.events,
  });

  final String familyLabel;
  final String summaryLabel;
  final String latestStatusLabel;
  final String recommendedActionLabel;
  final _DeliveryTimelineActionPriority actionPriority;
  final String actionPriorityLabel;
  final List<ChatDeliveryStatEvent> events;
}

class _DeliveryDiagnosticSummary {
  const _DeliveryDiagnosticSummary({
    required this.headline,
    required this.reason,
    required this.detail,
    required this.actionLabel,
    required this.actionDetail,
    required this.accent,
  });

  final String headline;
  final String reason;
  final String detail;
  final String actionLabel;
  final String actionDetail;
  final Color accent;
}

void showChatDeliveryStatsDebugSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: AppDialog.sheetAnimationStyle,
    builder: (sheetContext) => const _ChatDeliveryStatsDebugSheet(),
  );
}

class _ChatDeliveryStatsDebugSheet extends StatefulWidget {
  const _ChatDeliveryStatsDebugSheet();

  @override
  State<_ChatDeliveryStatsDebugSheet> createState() =>
      _ChatDeliveryStatsDebugSheetState();
}

class _ChatDeliveryStatsDebugSheetState
    extends State<_ChatDeliveryStatsDebugSheet> {
  _DeliveryTimelineFilter _selectedFilter = _DeliveryTimelineFilter.all;
  _DeliveryEventLevelFilter _selectedLevelFilter =
      _DeliveryEventLevelFilter.all;
  _DeliveryTimelineSortMode _selectedSortMode =
      _DeliveryTimelineSortMode.latest;
  _DeliveryTimelineViewMode _selectedViewMode = _DeliveryTimelineViewMode.full;

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final recentEvents = chatProvider.recentDeliveryEvents;
    final filteredEvents = _filterDeliveryEvents(
      recentEvents,
      _selectedFilter,
      _selectedLevelFilter,
    );
    final sortedEvents = _sortDeliveryEvents(filteredEvents, _selectedSortMode);
    final visibleEvents = _resolveVisibleDeliveryEvents(
      sortedEvents,
      _selectedViewMode,
    );
    final groupedEvents =
        _selectedViewMode == _DeliveryTimelineViewMode.recentAnomalies
            ? _sortDeliveryTimelineGroups(
                _groupDeliveryTimelineEvents(visibleEvents),
              )
            : const <_DeliveryTimelineGroup>[];
    final diagnosticSummary = _buildDiagnosticSummary(
      visibleEvents: visibleEvents,
      groupedEvents: groupedEvents,
      hasData: chatProvider.hasDeliveryStats,
      totalEvents: recentEvents.length,
    );
    final rows = <MapEntry<String, int>>[
      MapEntry('重试请求', chatProvider.deliveryStats['retries_requested'] ?? 0),
      MapEntry('重试成功', chatProvider.deliveryStats['retries_succeeded'] ?? 0),
      MapEntry('重试失败', chatProvider.deliveryStats['retries_failed'] ?? 0),
      MapEntry('文本成功', chatProvider.deliveryStats['text_succeeded'] ?? 0),
      MapEntry('文本失败', chatProvider.deliveryStats['text_failed'] ?? 0),
      MapEntry('图片成功', chatProvider.deliveryStats['image_succeeded'] ?? 0),
      MapEntry('图片失败', chatProvider.deliveryStats['image_failed'] ?? 0),
      MapEntry(
        '重选图片',
        chatProvider.deliveryStats['image_reselect_required'] ?? 0,
      ),
    ];

    final maxHeight = MediaQuery.of(context).size.height * 0.82;
    return Container(
      decoration: AppDialog.sheetDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '发送反馈统计',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '仅调试可见。',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!chatProvider.hasDeliveryStats)
                        _buildEmptyStatsCard()
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white05,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.white08),
                          ),
                          child: Column(
                            children: [
                              for (var index = 0;
                                  index < rows.length;
                                  index++) ...[
                                _buildStatsRow(
                                    rows[index].key, rows[index].value),
                                if (index != rows.length - 1)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    height: 1,
                                    color: AppColors.white05,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),
                      _buildDiagnosticSummaryCard(diagnosticSummary),
                      const SizedBox(height: 14),
                      _buildTimelineSection(
                        recentEvents: recentEvents,
                        visibleEvents: visibleEvents,
                        groupedEvents: groupedEvents,
                        hasData: chatProvider.hasDeliveryStats,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey<String>('chat-delivery-copy-summary'),
                      onPressed: () => _copyDebugSummary(
                        rows: rows,
                        visibleEvents: visibleEvents,
                        groupedEvents: groupedEvents,
                        diagnosticSummary: diagnosticSummary,
                        hasData: chatProvider.hasDeliveryStats,
                        totalEvents: recentEvents.length,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.white05,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.white08),
                        ),
                      ),
                      icon: const Icon(
                        Icons.content_copy_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      label: const Text(
                        '复制摘要',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey<String>('chat-delivery-clear-stats'),
                      onPressed: () {
                        context.read<ChatProvider>().resetDeliveryStats();
                        setState(() {
                          _selectedFilter = _DeliveryTimelineFilter.all;
                          _selectedLevelFilter = _DeliveryEventLevelFilter.all;
                          _selectedSortMode = _DeliveryTimelineSortMode.latest;
                          _selectedViewMode = _DeliveryTimelineViewMode.full;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.white08,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '清空统计',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white08),
      ),
      child: const Text(
        '暂无发送反馈统计',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatsRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticSummaryCard(_DeliveryDiagnosticSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: summary.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: summary.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '诊断结论',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: summary.accent,
                  ),
                ),
              ),
              _buildTag(summary.actionLabel, summary.accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary.actionDetail,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: summary.accent.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.headline,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '原因：${summary.reason}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: summary.accent,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary.detail,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection({
    required List<ChatDeliveryStatEvent> recentEvents,
    required List<ChatDeliveryStatEvent> visibleEvents,
    required List<_DeliveryTimelineGroup> groupedEvents,
    required bool hasData,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white05,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近发送轨迹',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '保留最近 20 条轨迹。',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: AppColors.textTertiary.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _DeliveryTimelineFilter.values.map((filter) {
              return _buildFilterChip(
                label:
                    '${_deliveryTimelineFilterLabel(filter)} · ${_countDeliveryEvents(recentEvents, filter, _DeliveryEventLevelFilter.all)}',
                selected: filter == _selectedFilter,
                onTap: () => setState(() => _selectedFilter = filter),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _DeliveryEventLevelFilter.values.map((filter) {
              return _buildFilterChip(
                label:
                    '${_deliveryLevelFilterLabel(filter)} · ${_countDeliveryEvents(recentEvents, _DeliveryTimelineFilter.all, filter)}',
                selected: filter == _selectedLevelFilter,
                onTap: () => setState(() => _selectedLevelFilter = filter),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _DeliveryTimelineSortMode.values.map((mode) {
              return _buildFilterChip(
                label: _deliverySortModeLabel(mode),
                selected: mode == _selectedSortMode,
                onTap: () => setState(() => _selectedSortMode = mode),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _DeliveryTimelineViewMode.values.map((mode) {
              return _buildFilterChip(
                label: _deliveryViewModeLabel(mode),
                selected: mode == _selectedViewMode,
                onTap: () => setState(() => _selectedViewMode = mode),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 14),
          if (visibleEvents.isEmpty)
            Text(
              _deliveryTimelineEmptyText(
                hasData: hasData,
                selectedFilter: _selectedFilter,
                selectedLevelFilter: _selectedLevelFilter,
                selectedViewMode: _selectedViewMode,
                totalEvents: recentEvents.length,
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
            )
          else if (_selectedViewMode ==
              _DeliveryTimelineViewMode.recentAnomalies)
            Column(
              children: [
                for (var index = 0; index < groupedEvents.length; index++) ...[
                  _buildGroupCard(groupedEvents[index]),
                  if (index != groupedEvents.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var index = 0; index < visibleEvents.length; index++) ...[
                  _buildTimelineItem(visibleEvents[index]),
                  if (index != visibleEvents.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      side: BorderSide(
        color: selected
            ? AppColors.brandBlue.withValues(alpha: 0.35)
            : AppColors.white08,
      ),
      backgroundColor: AppColors.white05,
      selectedColor: AppColors.brandBlue.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    );
  }

  Widget _buildGroupCard(_DeliveryTimelineGroup group) {
    final latestEvent = group.events.first;
    final accent =
        _deliveryLevelAccent(_resolveDeliveryEventLevel(latestEvent));
    final priorityAccent = _deliveryGroupActionPriorityAccent(
      group.actionPriority,
    );
    final isNeedsAction =
        group.actionPriority == _DeliveryTimelineActionPriority.needsAction;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isNeedsAction ? accent.withValues(alpha: 0.08) : AppColors.white05,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNeedsAction
              ? accent.withValues(alpha: 0.3)
              : accent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          group.familyLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        _buildTag(group.actionPriorityLabel, priorityAccent),
                      ],
                    ),
                    if (isNeedsAction) ...[
                      const SizedBox(height: 6),
                      Text(
                        '优先处理',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: priorityAccent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${group.latestStatusLabel} · ${_formatDeliveryEventTime(latestEvent.timestamp)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textTertiary.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.recommendedActionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildEventLevelBadge(latestEvent),
                  const SizedBox(height: 6),
                  _buildTag(group.summaryLabel, accent),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (var index = 0; index < group.events.length; index++) ...[
                _buildTimelineItem(group.events[index]),
                if (index != group.events.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ChatDeliveryStatEvent event) {
    final accent = _deliveryLevelAccent(_resolveDeliveryEventLevel(event));
    final icon =
        event.isError ? Icons.error_outline : Icons.check_circle_outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildEventLevelBadge(event),
                  const SizedBox(width: 6),
                  _buildTag(event.tagLabel, accent),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _formatDeliveryEventTime(event.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textTertiary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventLevelBadge(ChatDeliveryStatEvent event) {
    final level = _resolveDeliveryEventLevel(event);
    return _buildTag(
      _deliveryLevelBadgeLabel(level),
      _deliveryLevelAccent(level),
    );
  }

  Widget _buildTag(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: accent,
        ),
      ),
    );
  }

  List<ChatDeliveryStatEvent> _filterDeliveryEvents(
    List<ChatDeliveryStatEvent> events,
    _DeliveryTimelineFilter filter,
    _DeliveryEventLevelFilter levelFilter,
  ) {
    return events
        .where(
          (event) =>
              _matchesDeliveryTimelineFilter(event, filter) &&
              _matchesDeliveryLevelFilter(event, levelFilter),
        )
        .toList(growable: false);
  }

  List<ChatDeliveryStatEvent> _sortDeliveryEvents(
    List<ChatDeliveryStatEvent> events,
    _DeliveryTimelineSortMode mode,
  ) {
    final sortedEvents = List<ChatDeliveryStatEvent>.from(events);
    sortedEvents.sort((left, right) {
      if (mode == _DeliveryTimelineSortMode.anomaliesFirst) {
        final severityCompare = _deliveryEventSeverityScore(right)
            .compareTo(_deliveryEventSeverityScore(left));
        if (severityCompare != 0) {
          return severityCompare;
        }
      }
      return right.timestamp.compareTo(left.timestamp);
    });
    return sortedEvents;
  }

  List<ChatDeliveryStatEvent> _resolveVisibleDeliveryEvents(
    List<ChatDeliveryStatEvent> events,
    _DeliveryTimelineViewMode mode,
  ) {
    if (mode == _DeliveryTimelineViewMode.full) {
      return events;
    }
    return events
        .where((event) => _deliveryEventSeverityScore(event) > 0)
        .take(3)
        .toList(growable: false);
  }

  List<_DeliveryTimelineGroup> _groupDeliveryTimelineEvents(
    List<ChatDeliveryStatEvent> events,
  ) {
    if (events.isEmpty) {
      return const <_DeliveryTimelineGroup>[];
    }
    final groups = <_DeliveryTimelineGroup>[];
    var currentEvents = <ChatDeliveryStatEvent>[events.first];
    var currentFamily = _deliveryEventFamilyKey(events.first);

    for (var index = 1; index < events.length; index++) {
      final event = events[index];
      final family = _deliveryEventFamilyKey(event);
      final lastEvent = currentEvents.last;
      final withinWindow =
          lastEvent.timestamp.difference(event.timestamp).inMinutes.abs() <= 5;

      if (family == currentFamily && withinWindow) {
        currentEvents.add(event);
        continue;
      }

      groups.add(_buildDeliveryTimelineGroup(currentFamily, currentEvents));
      currentFamily = family;
      currentEvents = <ChatDeliveryStatEvent>[event];
    }

    groups.add(_buildDeliveryTimelineGroup(currentFamily, currentEvents));
    return groups;
  }

  List<_DeliveryTimelineGroup> _sortDeliveryTimelineGroups(
    List<_DeliveryTimelineGroup> groups,
  ) {
    final sortedGroups = List<_DeliveryTimelineGroup>.from(groups);
    sortedGroups.sort((left, right) {
      final priorityCompare = _deliveryGroupActionPriorityScore(right)
          .compareTo(_deliveryGroupActionPriorityScore(left));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return right.events.first.timestamp
          .compareTo(left.events.first.timestamp);
    });
    return sortedGroups;
  }

  _DeliveryTimelineGroup _buildDeliveryTimelineGroup(
    String family,
    List<ChatDeliveryStatEvent> events,
  ) {
    final latestEvent = events.first;
    final actionPriority = _resolveDeliveryGroupActionPriority(latestEvent);
    return _DeliveryTimelineGroup(
      familyLabel: _deliveryEventFamilyLabel(family),
      summaryLabel: '${events.length}步',
      latestStatusLabel: _deliveryGroupLatestStatusLabel(latestEvent),
      recommendedActionLabel: _deliveryGroupRecommendedActionLabel(latestEvent),
      actionPriority: actionPriority,
      actionPriorityLabel: _deliveryGroupActionPriorityLabel(actionPriority),
      events: List<ChatDeliveryStatEvent>.unmodifiable(events),
    );
  }

  bool _matchesDeliveryTimelineFilter(
    ChatDeliveryStatEvent event,
    _DeliveryTimelineFilter filter,
  ) {
    switch (filter) {
      case _DeliveryTimelineFilter.all:
        return true;
      case _DeliveryTimelineFilter.failures:
        return event.isError;
      case _DeliveryTimelineFilter.retries:
        return event.code.startsWith('retries_') || event.tagLabel == '重试';
      case _DeliveryTimelineFilter.images:
        return event.code.startsWith('image_') || event.tagLabel == '图片';
    }
  }

  int _countDeliveryEvents(
    List<ChatDeliveryStatEvent> events,
    _DeliveryTimelineFilter filter,
    _DeliveryEventLevelFilter levelFilter,
  ) {
    return events
        .where(
          (event) =>
              _matchesDeliveryTimelineFilter(event, filter) &&
              _matchesDeliveryLevelFilter(event, levelFilter),
        )
        .length;
  }

  bool _matchesDeliveryLevelFilter(
    ChatDeliveryStatEvent event,
    _DeliveryEventLevelFilter filter,
  ) {
    switch (filter) {
      case _DeliveryEventLevelFilter.all:
        return true;
      case _DeliveryEventLevelFilter.recovered:
        return _resolveDeliveryEventLevel(event) ==
            _DeliveryEventLevelFilter.recovered;
      case _DeliveryEventLevelFilter.blocked:
        return _resolveDeliveryEventLevel(event) ==
            _DeliveryEventLevelFilter.blocked;
      case _DeliveryEventLevelFilter.reselect:
        return _resolveDeliveryEventLevel(event) ==
            _DeliveryEventLevelFilter.reselect;
    }
  }

  String _deliveryTimelineFilterLabel(_DeliveryTimelineFilter filter) {
    switch (filter) {
      case _DeliveryTimelineFilter.all:
        return '全部';
      case _DeliveryTimelineFilter.failures:
        return '失败';
      case _DeliveryTimelineFilter.retries:
        return '重试';
      case _DeliveryTimelineFilter.images:
        return '图片';
    }
  }

  String _deliveryLevelFilterLabel(_DeliveryEventLevelFilter filter) {
    switch (filter) {
      case _DeliveryEventLevelFilter.all:
        return '全部级别';
      case _DeliveryEventLevelFilter.recovered:
        return '成功恢复';
      case _DeliveryEventLevelFilter.blocked:
        return '失败阻断';
      case _DeliveryEventLevelFilter.reselect:
        return '需要重选';
    }
  }

  String _deliveryLevelBadgeLabel(_DeliveryEventLevelFilter filter) {
    switch (filter) {
      case _DeliveryEventLevelFilter.all:
        return '常规';
      case _DeliveryEventLevelFilter.recovered:
        return '恢复';
      case _DeliveryEventLevelFilter.blocked:
        return '阻断';
      case _DeliveryEventLevelFilter.reselect:
        return '重选';
    }
  }

  String _deliverySortModeLabel(_DeliveryTimelineSortMode mode) {
    switch (mode) {
      case _DeliveryTimelineSortMode.latest:
        return '最新优先';
      case _DeliveryTimelineSortMode.anomaliesFirst:
        return '异常优先';
    }
  }

  String _deliveryViewModeLabel(_DeliveryTimelineViewMode mode) {
    switch (mode) {
      case _DeliveryTimelineViewMode.full:
        return '完整轨迹';
      case _DeliveryTimelineViewMode.recentAnomalies:
        return '最近异常';
    }
  }

  String _deliveryEventFamilyKey(ChatDeliveryStatEvent event) {
    if (event.code.startsWith('image_')) {
      return 'image';
    }
    if (event.code.startsWith('retries_')) {
      return 'retry';
    }
    if (event.code.startsWith('text_')) {
      return 'text';
    }
    return 'other';
  }

  String _deliveryEventFamilyLabel(String family) {
    switch (family) {
      case 'image':
        return '图片链路';
      case 'retry':
        return '重试链路';
      case 'text':
        return '文本链路';
      case 'other':
        return '其他链路';
    }
    return '其他链路';
  }

  String _deliveryGroupLatestStatusLabel(ChatDeliveryStatEvent event) {
    switch (_resolveDeliveryEventLevel(event)) {
      case _DeliveryEventLevelFilter.recovered:
        return '状态：已恢复送达';
      case _DeliveryEventLevelFilter.blocked:
        return '状态：发送阻断';
      case _DeliveryEventLevelFilter.reselect:
        return '状态：需重新选图';
      case _DeliveryEventLevelFilter.all:
        return '状态：常规记录';
    }
  }

  String _deliveryGroupRecommendedActionLabel(ChatDeliveryStatEvent event) {
    switch (_resolveDeliveryEventLevel(event)) {
      case _DeliveryEventLevelFilter.recovered:
        return '已恢复送达，无需处理';
      case _DeliveryEventLevelFilter.blocked:
        return '稍后重试或检查网络';
      case _DeliveryEventLevelFilter.reselect:
        return '重新选图后再发送';
      case _DeliveryEventLevelFilter.all:
        return '继续观察';
    }
  }

  _DeliveryTimelineActionPriority _resolveDeliveryGroupActionPriority(
    ChatDeliveryStatEvent event,
  ) {
    switch (_resolveDeliveryEventLevel(event)) {
      case _DeliveryEventLevelFilter.blocked:
      case _DeliveryEventLevelFilter.reselect:
        return _DeliveryTimelineActionPriority.needsAction;
      case _DeliveryEventLevelFilter.recovered:
        return _DeliveryTimelineActionPriority.resolved;
      case _DeliveryEventLevelFilter.all:
        return _DeliveryTimelineActionPriority.monitoring;
    }
  }

  String _deliveryGroupActionPriorityLabel(
    _DeliveryTimelineActionPriority priority,
  ) {
    switch (priority) {
      case _DeliveryTimelineActionPriority.needsAction:
        return '待处理';
      case _DeliveryTimelineActionPriority.monitoring:
        return '继续观察';
      case _DeliveryTimelineActionPriority.resolved:
        return '已恢复';
    }
  }

  Color _deliveryGroupActionPriorityAccent(
    _DeliveryTimelineActionPriority priority,
  ) {
    switch (priority) {
      case _DeliveryTimelineActionPriority.needsAction:
        return AppColors.warning;
      case _DeliveryTimelineActionPriority.monitoring:
        return AppColors.textSecondary;
      case _DeliveryTimelineActionPriority.resolved:
        return AppColors.success;
    }
  }

  int _deliveryGroupActionPriorityScore(_DeliveryTimelineGroup group) {
    switch (group.actionPriority) {
      case _DeliveryTimelineActionPriority.needsAction:
        return 2;
      case _DeliveryTimelineActionPriority.monitoring:
        return 1;
      case _DeliveryTimelineActionPriority.resolved:
        return 0;
    }
  }

  _DeliveryEventLevelFilter _resolveDeliveryEventLevel(
    ChatDeliveryStatEvent event,
  ) {
    if (event.code == ChatDeliveryStatsService.imageReselectRequiredKey) {
      return _DeliveryEventLevelFilter.reselect;
    }
    if (event.code == ChatDeliveryStatsService.retriesSucceededKey) {
      return _DeliveryEventLevelFilter.recovered;
    }
    if (event.code == ChatDeliveryStatsService.retriesFailedKey ||
        event.code == ChatDeliveryStatsService.textFailedKey ||
        event.code == ChatDeliveryStatsService.imageFailedKey) {
      return _DeliveryEventLevelFilter.blocked;
    }
    return _DeliveryEventLevelFilter.all;
  }

  Color _deliveryLevelAccent(_DeliveryEventLevelFilter filter) {
    switch (filter) {
      case _DeliveryEventLevelFilter.all:
        return AppColors.textSecondary;
      case _DeliveryEventLevelFilter.recovered:
        return AppColors.brandBlue;
      case _DeliveryEventLevelFilter.blocked:
        return AppColors.error;
      case _DeliveryEventLevelFilter.reselect:
        return AppColors.warning;
    }
  }

  int _deliveryEventSeverityScore(ChatDeliveryStatEvent event) {
    switch (_resolveDeliveryEventLevel(event)) {
      case _DeliveryEventLevelFilter.reselect:
        return 3;
      case _DeliveryEventLevelFilter.blocked:
        return 2;
      case _DeliveryEventLevelFilter.recovered:
        return 1;
      case _DeliveryEventLevelFilter.all:
        return 0;
    }
  }

  String _deliveryTimelineEmptyText({
    required bool hasData,
    required _DeliveryTimelineFilter selectedFilter,
    required _DeliveryEventLevelFilter selectedLevelFilter,
    required _DeliveryTimelineViewMode selectedViewMode,
    required int totalEvents,
  }) {
    if (!hasData) {
      return '暂无最近发送轨迹';
    }
    if (totalEvents == 0) {
      return '统计已保留，最近还没有新轨迹';
    }
    if (selectedViewMode == _DeliveryTimelineViewMode.recentAnomalies) {
      return '当前条件下暂无最近异常轨迹';
    }
    switch (selectedLevelFilter) {
      case _DeliveryEventLevelFilter.recovered:
        return '当前筛选下暂无成功恢复轨迹';
      case _DeliveryEventLevelFilter.blocked:
        return '当前筛选下暂无失败阻断轨迹';
      case _DeliveryEventLevelFilter.reselect:
        return '当前筛选下暂无重选图片轨迹';
      case _DeliveryEventLevelFilter.all:
        break;
    }
    switch (selectedFilter) {
      case _DeliveryTimelineFilter.all:
        return '暂无发送轨迹';
      case _DeliveryTimelineFilter.failures:
        return '暂无失败轨迹';
      case _DeliveryTimelineFilter.retries:
        return '暂无重试轨迹';
      case _DeliveryTimelineFilter.images:
        return '暂无图片轨迹';
    }
  }

  String _formatDeliveryEventTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return '刚刚';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    }
    return '${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  }

  Future<void> _copyDebugSummary({
    required List<MapEntry<String, int>> rows,
    required List<ChatDeliveryStatEvent> visibleEvents,
    required List<_DeliveryTimelineGroup> groupedEvents,
    required _DeliveryDiagnosticSummary diagnosticSummary,
    required bool hasData,
    required int totalEvents,
  }) async {
    final summary = _buildDebugSummary(
      rows: rows,
      visibleEvents: visibleEvents,
      groupedEvents: groupedEvents,
      diagnosticSummary: diagnosticSummary,
      hasData: hasData,
      totalEvents: totalEvents,
    );
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    AppFeedback.showToast(context, AppToastCode.copied);
  }

  String _buildDebugSummary({
    required List<MapEntry<String, int>> rows,
    required List<ChatDeliveryStatEvent> visibleEvents,
    required List<_DeliveryTimelineGroup> groupedEvents,
    required _DeliveryDiagnosticSummary diagnosticSummary,
    required bool hasData,
    required int totalEvents,
  }) {
    final buffer = StringBuffer()
      ..writeln('发送反馈统计')
      ..writeln('导出时间：${_formatDeliveryExportTime(DateTime.now())}')
      ..writeln(
        '当前筛选：${_deliveryTimelineFilterLabel(_selectedFilter)} / ${_deliveryLevelFilterLabel(_selectedLevelFilter)} / ${_deliverySortModeLabel(_selectedSortMode)} / ${_deliveryViewModeLabel(_selectedViewMode)}',
      )
      ..writeln('')
      ..writeln('诊断结论')
      ..writeln('- ${diagnosticSummary.headline}')
      ..writeln('- 建议：${diagnosticSummary.actionLabel}')
      ..writeln('- 状态：${diagnosticSummary.actionDetail}')
      ..writeln('- 原因：${diagnosticSummary.reason}')
      ..writeln('- ${diagnosticSummary.detail}')
      ..writeln('')
      ..writeln('统计概览');

    for (final row in rows) {
      buffer.writeln('- ${row.key}：${row.value}');
    }

    buffer
      ..writeln('')
      ..writeln('轨迹摘要');

    if (!hasData) {
      buffer.writeln('- 暂无发送反馈统计');
      return buffer.toString().trimRight();
    }

    if (totalEvents == 0 || visibleEvents.isEmpty) {
      buffer.writeln(
        '- ${_deliveryTimelineEmptyText(
          hasData: hasData,
          selectedFilter: _selectedFilter,
          selectedLevelFilter: _selectedLevelFilter,
          selectedViewMode: _selectedViewMode,
          totalEvents: totalEvents,
        )}',
      );
      return buffer.toString().trimRight();
    }

    if (_selectedViewMode == _DeliveryTimelineViewMode.recentAnomalies &&
        groupedEvents.isNotEmpty) {
      for (var index = 0; index < groupedEvents.length; index++) {
        final group = groupedEvents[index];
        buffer.writeln(
          '${index + 1}. ${group.familyLabel}｜${group.summaryLabel}｜${group.latestStatusLabel.replaceFirst('状态：', '')}｜${group.recommendedActionLabel}',
        );
      }
      return buffer.toString().trimRight();
    }

    final exportEvents = visibleEvents.take(5).toList(growable: false);
    for (var index = 0; index < exportEvents.length; index++) {
      final event = exportEvents[index];
      buffer.writeln(
        '${index + 1}. ${event.label}｜${event.tagLabel}｜${_deliveryLevelBadgeLabel(_resolveDeliveryEventLevel(event))}｜${_formatDeliveryExportTime(event.timestamp)}',
      );
    }
    return buffer.toString().trimRight();
  }

  String _formatDeliveryExportTime(DateTime timestamp) {
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '${timestamp.year}-$month-$day $hour:$minute';
  }

  _DeliveryDiagnosticSummary _buildDiagnosticSummary({
    required List<ChatDeliveryStatEvent> visibleEvents,
    required List<_DeliveryTimelineGroup> groupedEvents,
    required bool hasData,
    required int totalEvents,
  }) {
    if (!hasData) {
      return const _DeliveryDiagnosticSummary(
        headline: '当前没有可诊断数据',
        reason: '最近还没有形成有效样本。',
        detail: '有新轨迹后，这里会生成结论。',
        actionLabel: '等待数据',
        actionDetail: '当前还没有可分诊的异常轨迹。',
        accent: AppColors.textSecondary,
      );
    }

    if (totalEvents == 0 || visibleEvents.isEmpty) {
      return _DeliveryDiagnosticSummary(
        headline: '当前筛选下没有命中轨迹',
        reason: '当前筛选没有命中可展示事件。',
        detail: _deliveryTimelineEmptyText(
          hasData: hasData,
          selectedFilter: _selectedFilter,
          selectedLevelFilter: _selectedLevelFilter,
          selectedViewMode: _selectedViewMode,
          totalEvents: totalEvents,
        ),
        actionLabel: '调整筛选',
        actionDetail: '当前筛选没有命中需处理轨迹。',
        accent: AppColors.textSecondary,
      );
    }

    if (groupedEvents.isNotEmpty) {
      final focusGroup = groupedEvents.first;
      final focusEvent = focusGroup.events.first;
      return _DeliveryDiagnosticSummary(
        headline:
            '优先处理：${focusGroup.familyLabel}${focusGroup.latestStatusLabel.replaceFirst('状态：', '')}',
        reason:
            _diagnosticReasonForLevel(_resolveDeliveryEventLevel(focusEvent)),
        detail: _diagnosticDetailForGroup(focusGroup),
        actionLabel: _diagnosticActionLabelForLevel(
          _resolveDeliveryEventLevel(focusEvent),
        ),
        actionDetail: _diagnosticActionDetailForEvent(focusEvent),
        accent: _deliveryGroupActionPriorityAccent(focusGroup.actionPriority),
      );
    }

    final prioritizedEvents = List<ChatDeliveryStatEvent>.from(visibleEvents)
      ..sort((left, right) {
        final severityCompare = _deliveryEventSeverityScore(right)
            .compareTo(_deliveryEventSeverityScore(left));
        if (severityCompare != 0) {
          return severityCompare;
        }
        return right.timestamp.compareTo(left.timestamp);
      });
    final topEvent = prioritizedEvents.first;
    final level = _resolveDeliveryEventLevel(topEvent);
    final headline = switch (level) {
      _DeliveryEventLevelFilter.reselect => '优先处理：图片需重选',
      _DeliveryEventLevelFilter.blocked => '优先处理：发送待恢复',
      _DeliveryEventLevelFilter.recovered => '最近已恢复送达',
      _DeliveryEventLevelFilter.all => '当前以常规发送为主',
    };
    final detail = switch (level) {
      _DeliveryEventLevelFilter.reselect => '重新选图后再发送',
      _DeliveryEventLevelFilter.blocked => '先检查网络或稍后重试',
      _DeliveryEventLevelFilter.recovered => '已恢复送达，继续观察',
      _DeliveryEventLevelFilter.all => '暂无阻断异常，继续观察',
    };
    return _DeliveryDiagnosticSummary(
      headline: headline,
      reason: _diagnosticReasonForLevel(level),
      detail: detail,
      actionLabel: _diagnosticActionLabelForLevel(level),
      actionDetail: _diagnosticActionDetailForEvent(topEvent),
      accent: _deliveryLevelAccent(level),
    );
  }

  String _diagnosticActionLabelForLevel(_DeliveryEventLevelFilter level) {
    switch (level) {
      case _DeliveryEventLevelFilter.reselect:
        return '建议重选图片';
      case _DeliveryEventLevelFilter.blocked:
        return '建议检查网络';
      case _DeliveryEventLevelFilter.recovered:
        return '无需处理';
      case _DeliveryEventLevelFilter.all:
        return '继续观察';
    }
  }

  String _diagnosticReasonForLevel(_DeliveryEventLevelFilter level) {
    switch (level) {
      case _DeliveryEventLevelFilter.reselect:
        return '原图资源已失效，原消息无法直接恢复。';
      case _DeliveryEventLevelFilter.blocked:
        return '消息停在失败阻断态，通常与网络或投递失败有关。';
      case _DeliveryEventLevelFilter.recovered:
        return '最近一次异常已恢复，当前链路重新可用。';
      case _DeliveryEventLevelFilter.all:
        return '最近以常规发送记录为主，没有更高优先级异常。';
    }
  }

  String _diagnosticActionDetailForEvent(ChatDeliveryStatEvent event) {
    switch (event.code) {
      case ChatDeliveryStatsService.imageReselectRequiredKey:
        return '原图已失效，需要重选。';
      case ChatDeliveryStatsService.retriesFailedKey:
        return '最近一次重试仍未送达。';
      case ChatDeliveryStatsService.imageFailedKey:
        return '图片发送仍处于阻断。';
      case ChatDeliveryStatsService.textFailedKey:
        return '当前发送仍处于阻断。';
      case ChatDeliveryStatsService.retriesSucceededKey:
        return '最近一次重试已恢复送达。';
      default:
        return '当前没有更高优先级异常。';
    }
  }

  String _diagnosticDetailForGroup(_DeliveryTimelineGroup group) {
    switch (group.actionPriority) {
      case _DeliveryTimelineActionPriority.needsAction:
        return '异常集中在${group.familyLabel}，共${group.summaryLabel}。';
      case _DeliveryTimelineActionPriority.monitoring:
        return '当前主要是${group.familyLabel}常规发送，共${group.summaryLabel}。';
      case _DeliveryTimelineActionPriority.resolved:
        return '异常已在${group.familyLabel}恢复，共${group.summaryLabel}。';
    }
  }
}
