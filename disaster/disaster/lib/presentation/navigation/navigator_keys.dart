import 'package:flutter/material.dart';

/// Global navigator used to deep-link from notification taps (and any
/// push-message payload) into the alert detail screen.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();