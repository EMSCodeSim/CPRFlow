import 'package:cpr_instructor_doc/app/app_routes.dart';
import 'package:cpr_instructor_doc/app/app_scope.dart';
import 'package:cpr_instructor_doc/data/local/app_database.dart';
import 'package:cpr_instructor_doc/ui/widgets/keyboard_dismiss.dart';
import 'package:cpr_instructor_doc/ui/widgets/database_error_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return KeyboardDismiss(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CCF Timer'),
          actions: [
            IconButton(
              tooltip: 'Current class',
              onPressed: services.hasClassData ? () => _showClassSelector(context) : null,
              icon: const Icon(Icons.school_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: !services.hasClassData
                ? _DisabledModePanel()
                : StreamBuilder<ClassRecord?>(
                    stream: services.classRepository.watchActiveClass(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return DatabaseErrorPanel(
                          message: 'Class data could not be loaded.',
                          error: snapshot.error,
                          onRetry: () => context.go(AppRoutes.home),
                          onOpenRecovery: () => _showRecoveryInfo(context),
                        );
                      }
                      final active = snapshot.data;
                      if (active == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('No active class', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Create your first class to begin managing students.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.78)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final existing = await services.classRepository.getActiveClass();
                                  if (existing != null) {
                                    if (context.mounted) await _showActiveClassConflictSheet(context, existing);
                                    return;
                                  }
                                  if (context.mounted) context.push('${AppRoutes.classEdit}?mode=create');
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Create Class'),
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView(
                        children: [
                          _ActiveClassCard(active: active),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => context.go(AppRoutes.today),
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text("Continue Today's Class"),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('${AppRoutes.classEdit}?id=${Uri.encodeComponent(active.id)}'),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit Class'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push(AppRoutes.studentAdd),
                                  icon: const Icon(Icons.person_add_alt_1_outlined),
                                  label: const Text('Add Student'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => context.push(AppRoutes.ccfTimer),
                              icon: const Icon(Icons.timer_outlined),
                              label: const Text('Standalone CCF Timer'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                              border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Archive (Phase 3)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text(
                                  'View previously finalized classes and create working copies.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.78)),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => context.push(AppRoutes.archive),
                                    icon: const Icon(Icons.archive_outlined),
                                    label: const Text('Open Archive'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showClassSelector(BuildContext context) async {
    final services = AppScope.of(context);
    if (!services.hasClassData) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: StreamBuilder<List<ClassRecord>>(
              stream: services.classRepository.watchAllClasses(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return DatabaseErrorPanel(
                    title: 'Class list could not be loaded.',
                    message: 'Try again. If this persists, open recovery mode from startup.',
                    error: snapshot.error,
                    onRetry: () => context.go(AppRoutes.home),
                    onOpenRecovery: () => _showRecoveryInfo(context),
                  );
                }
                final classes = snapshot.data ?? const [];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current class', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (classes.isEmpty)
                      const Text('No classes found.')
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: classes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final c = classes[index];
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                              leading: Icon(c.isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                              title: Text(c.className),
                              subtitle: Text(c.courseType == CourseType.blsProvider ? 'BLS Provider' : 'Course'),
                              onTap: () async {
                                final active = await services.classRepository.getActiveClass();
                                if (active != null && active.id != c.id) {
                                  if (!context.mounted) return;
                                  context.pop();
                                  await _showActiveClassConflictSheet(context, active);
                                  return;
                                }
                                try {
                                  await services.classRepository.setActiveClass(c.id);
                                } catch (_) {
                                  if (!context.mounted) return;
                                  context.pop();
                                  if (active != null) await _showActiveClassConflictSheet(context, active);
                                  return;
                                }
                                if (context.mounted) context.pop();
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final active = await services.classRepository.getActiveClass();
                          if (active != null) {
                            if (context.mounted) {
                              context.pop();
                              await _showActiveClassConflictSheet(context, active);
                            }
                            return;
                          }
                          if (context.mounted) {
                            context.pop();
                            context.push('${AppRoutes.classEdit}?mode=create');
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create another class'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showActiveClassBlockingCreateDialog(BuildContext context) async {
    // Kept for compatibility; prefer the sheet which includes class details.
    await _showActiveClassConflictSheet(context, await AppScope.of(context).classRepository.getActiveClass() ?? (throw StateError('No active class')));
  }

  Future<void> _showActiveClassConflictSheet(BuildContext context, ClassRecord active) async {
    final loc = MaterialLocalizations.of(context);
    final dateText = active.classDate == null ? 'Unknown date' : loc.formatMediumDate(active.classDate!);
    final subtitleParts = <String>[dateText];
    if ((active.location ?? '').trim().isNotEmpty) subtitleParts.add(active.location!.trim());
    final subtitle = subtitleParts.join(' • ');

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Class in Progress', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Another class cannot become active while a current class is in progress.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.82)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.school_outlined),
                  title: Text(active.className),
                  subtitle: Text(subtitle),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
                  ),
                  child: Text('To switch classes, finalize the current class or cancel the action.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.pop();
                          context.push(AppRoutes.finalizeClass);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Finalize Current Class'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          context.pop();
                          context.go(AppRoutes.home);
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Return to Current Class'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRecoveryInfo(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recovery'),
          content: const Text(
            'If class data continues to fail loading, restart the app to enter Startup Recovery and choose Retry or Open Without Class Data.',
          ),
          actions: [TextButton(onPressed: () => context.pop(), child: const Text('OK'))],
        );
      },
    );
  }
}

class _DisabledModePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 54, color: scheme.primary),
            const SizedBox(height: 12),
            Text('Class data disabled', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'You opened without class data from the recovery screen. Create/edit class and student features are disabled in this mode.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveClassCard extends StatelessWidget {
  const _ActiveClassCard({required this.active});

  final ClassRecord active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current class', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75))),
          const SizedBox(height: 6),
          Text(active.className, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            active.courseType == CourseType.blsProvider ? 'BLS Provider' : 'Course',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.today),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Open Today's Class"),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('${AppRoutes.todayReports}?classId=${active.id}'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Reports'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.onTap});

  final StudentRecord student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      leading: const Icon(Icons.person_outline),
      title: Text(student.displayName),
      subtitle: student.nameNeedsReview ? Text('Name needs review', style: TextStyle(color: scheme.error)) : null,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
