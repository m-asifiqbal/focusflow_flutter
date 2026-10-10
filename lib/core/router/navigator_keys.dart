/// Navigator keys shared by the router and feature route files.
///
/// Full-screen routes (editors, details, search…) use
/// `parentNavigatorKey: rootNavigatorKey` so they cover the tab bar.
library;

import 'package:flutter/widgets.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
