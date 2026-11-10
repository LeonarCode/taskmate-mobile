import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'theme.dart';

/// A message fit to show the user for any error.
String errorText(Object error) => error is ApiException
    ? error.message
    : error.toString().replaceFirst('Exception: ', '');

void showErrorSnack(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(errorText(error)),
        backgroundColor: AppColors.red500,
      ),
    );
}

void showInfoSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shows [builder] as a rounded bottom sheet that sits above the keyboard.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}
