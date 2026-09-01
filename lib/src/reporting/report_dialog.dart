import 'dart:math';
import 'package:flutter/material.dart';
import '../../l10n/l10n_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/flux_theme.dart';
import 'report_service.dart';

class ReportDialog extends StatefulWidget {
  const ReportDialog({
    super.key,
    required this.assistantResponse,
    this.userPrompt,
    required this.modelTier,
    this.appVersion,
  });

  final String assistantResponse;
  final String? userPrompt;
  final String modelTier;
  final String? appVersion;

  static Future<void> show(
    BuildContext context, {
    required String assistantResponse,
    String? userPrompt,
    required String modelTier,
    String? appVersion,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReportDialog(
        assistantResponse: assistantResponse,
        userPrompt: userPrompt,
        modelTier: modelTier,
        appVersion: appVersion,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  ReportCategory _category = ReportCategory.harmfulOrDangerous;
  bool _includePrompt = false;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String _resolvedVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    if (widget.appVersion != null && widget.appVersion!.isNotEmpty) {
      _resolvedVersion = widget.appVersion!;
      return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _resolvedVersion = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final randomId =
        (DateTime.now().microsecondsSinceEpoch ^ Random().nextInt(1000000))
            .toString();
    final payload = ReportPayload(
      reportId: randomId,
      category: _category,
      assistantResponse: widget.assistantResponse,
      timestamp: DateTime.now(),
      appVersion: _resolvedVersion,
      modelTier: widget.modelTier,
      userPrompt: _includePrompt ? widget.userPrompt : null,
      additionalDetails: _detailsController.text.trim(),
    );

    final emailUri = ReportService.instance.buildEmailUri(payload);
    var opened = false;
    if (emailUri != null) {
      try {
        opened = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (opened) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).reportReviewInEmail),
            duration: Duration(seconds: 4),
          ),
        );
    } else {
      setState(() {
        _errorMessage =
            'No email app could be opened. Email finn_org@proton.me directly.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluxColors.isDark(context);
    final textTheme = Theme.of(context).textTheme;
    final isConfigured = ReportService.instance.canComposeEmail;

    return AlertDialog(
      backgroundColor: isDark
          ? const Color(0xFF1F1F23)
          : const Color(0xFFF7F8F4),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Icon(Icons.flag_outlined, color: FluxColors.inkOf(context), size: 24),
          const SizedBox(width: 10),
          Text(
            L10n.of(context).reportTitle,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isConfigured) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x33F59E0B)
                      : const Color(0x22F59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        L10n.of(context).reportNotConfigured,
                        style: textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              L10n.of(context).reportSubtitle,
              style: textTheme.bodySmall?.copyWith(
                color: FluxColors.mutedOf(context),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              L10n.of(context).reportReasonLabel,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FluxColors.lineOf(context)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ReportCategory>(
                  value: _category,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? const Color(0xFF27272A)
                      : Colors.white,
                  items: ReportCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.displayName, style: textTheme.bodyMedium),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _category = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              L10n.of(context).reportResponsePreview,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(maxHeight: 90),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x33000000)
                    : const Color(0x11000000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FluxColors.lineOf(context)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.assistantResponse,
                  style: textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
            ),
            if (widget.userPrompt != null && widget.userPrompt!.isNotEmpty) ...[
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  L10n.of(context).reportIncludePrompt,
                  style: textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
                value: _includePrompt,
                activeColor: FluxColors.inkOf(context),
                onChanged: (val) =>
                    setState(() => _includePrompt = val ?? false),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 2,
              style: textTheme.bodySmall,
              decoration: InputDecoration(
                hintText: 'Optional additional details...',
                hintStyle: textTheme.bodySmall?.copyWith(
                  color: FluxColors.mutedOf(context),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: FluxColors.lineOf(context)),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFFD32F2F),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              L10n.of(context).reportContinueHint,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: FluxColors.mutedOf(context),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(L10n.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: (_isSubmitting || !isConfigured) ? null : _submitReport,
          style: FilledButton.styleFrom(
            backgroundColor: FluxColors.inkOf(context),
            foregroundColor: FluxColors.canvasOf(context),
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FluxColors.canvasOf(context),
                  ),
                )
              : Text(L10n.of(context).reportContinueToEmail),
        ),
      ],
    );
  }
}
