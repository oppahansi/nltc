// Flutter Imports
import "package:flutter/material.dart";

double screenWidth(BuildContext context, double percent) =>
    MediaQuery.of(context).size.width * percent;

double screenHeight(BuildContext context, double percent) =>
    MediaQuery.of(context).size.height * percent;

/// Device classes based on shortestSide (logical pixels).
/// - Small phone: < 360dp  (e.g., 4.0" 480x800 emulator ≈ 320dp width)
/// - Medium phone: 360–399dp (older 5.0" devices at 360dp width)
/// - Normal phone: 400–599dp (most modern phones, e.g., 411dp, 432dp)
/// - Tablet: >= 600dp
enum DeviceClass { smallPhone, mediumPhone, phone, tablet }

DeviceClass deviceClassOf(BuildContext context) {
  final s = MediaQuery.sizeOf(context).shortestSide; // orientation-agnostic
  if (s < 360) return DeviceClass.smallPhone;
  if (s < 400) return DeviceClass.mediumPhone;
  if (s < 600) return DeviceClass.phone;
  return DeviceClass.tablet;
}

// Convenience helpers
bool isSmallPhone(BuildContext context) =>
    deviceClassOf(context) == DeviceClass.smallPhone;
bool isMediumPhone(BuildContext context) =>
    deviceClassOf(context) == DeviceClass.mediumPhone;
bool isNormalPhone(BuildContext context) =>
    deviceClassOf(context) == DeviceClass.phone;
bool isTablet(BuildContext context) =>
    deviceClassOf(context) == DeviceClass.tablet;
bool isLargeTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 840; // optional finer split

/// Optional: Material 3 window size classes (by width).
/// Useful for responsive layouts across phones/tablets/desktops.
/// - compact: < 600dp, medium: 600–839dp, expanded: >= 840dp
enum WindowSizeClass { compact, medium, expanded }

WindowSizeClass windowSizeClassOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 600) return WindowSizeClass.compact;
  if (w < 840) return WindowSizeClass.medium;
  return WindowSizeClass.expanded;
}

double gapSize(BuildContext context) => screenWidth(context, 0.05);
double gapSizeSmall(BuildContext context) => screenWidth(context, 0.02);
double gapSizeLarge(BuildContext context) => screenWidth(context, 0.1);
