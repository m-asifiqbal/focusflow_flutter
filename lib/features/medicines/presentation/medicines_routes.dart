/// Routes owned by the medicines feature (list, editor, detail).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/medicines/presentation/screens/medicine_detail_screen.dart';
import 'package:focusflow/features/medicines/presentation/screens/medicine_editor_screen.dart';
import 'package:focusflow/features/medicines/presentation/screens/medicines_list_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/medicines`.
final List<RouteBase> medicinesLibraryRoutes = [
  GoRoute(
    path: 'medicines',
    builder: (context, state) => const MedicinesListScreen(),
  ),
];

/// `/medicines/new?name=`, `/medicines/:id` (detail), `/medicines/:id/edit`.
final List<RouteBase> medicinesRootRoutes = [
  GoRoute(
    path: '/medicines/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        MedicineEditorScreen(initialName: state.uri.queryParameters['name']),
  ),
  GoRoute(
    path: '/medicines/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        MedicineDetailScreen(medicineId: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MedicineEditorScreen(medicineId: state.pathParameters['id']),
      ),
    ],
  ),
];
