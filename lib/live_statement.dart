import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'labels.dart';

/// Renders the same native PDF used for export. A revision token prevents a
/// slow older render from replacing the current settings, including on errors.
class LiveStatementPreview extends StatefulWidget {
  final String fingerprint;
  final Future<Uint8List> Function()? buildPdf;
  final String? error;
  final bool gestures;
  final VoidCallback onOpen;
  final Future<List<Uint8List>> Function(Uint8List)? rasterize;
  const LiveStatementPreview({
    super.key,
    required this.fingerprint,
    required this.buildPdf,
    required this.onOpen,
    this.error,
    this.gestures = true,
    this.rasterize,
  });
  @override
  State<LiveStatementPreview> createState() => _LiveStatementPreviewState();
}

class _LiveStatementPreviewState extends State<LiveStatementPreview> {
  Timer? debounce;
  int revision = 0, page = 0;
  bool expanded = false, pending = true;
  String? failure;
  List<Uint8List> pages = [];
  final pager = PageController();
  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(covariant LiveStatementPreview old) {
    super.didUpdateWidget(old);
    if (old.fingerprint != widget.fingerprint) schedule();
  }

  void schedule() {
    debounce?.cancel();
    final token = ++revision;
    pending = true;
    failure = widget.error;
    // Never leave a stale document visible under a newly selected filter.
    pages = [];
    page = 0;
    if (widget.buildPdf == null) {
      pending = false;
      return;
    }
    final builder = widget.buildPdf!;
    debounce = Timer(
      const Duration(milliseconds: 280),
      () => render(token, builder),
    );
  }

  Future<void> render(int token, Future<Uint8List> Function() builder) async {
    try {
      final bytes = await builder();
      if (!mounted || token != revision) return;
      final result = <Uint8List>[];
      if (widget.rasterize != null) {
        result.addAll(await widget.rasterize!(bytes));
      } else {
        await for (final raster in Printing.raster(bytes, dpi: 85)) {
          if (!mounted || token != revision) return;
          result.add(await raster.toPng());
        }
      }
      if (!mounted || token != revision) return;
      setState(() {
        pages = result;
        pending = false;
        failure = result.isEmpty ? 'الكشف خالٍ من الصفحات' : null;
      });
      if (pager.hasClients) pager.jumpToPage(0);
    } catch (_) {
      if (mounted && token == revision)
        setState(() {
          pending = false;
          failure = 'تعذّر تحديث المعاينة. اضغط إعادة المحاولة.';
        });
    }
  }

  void move(int delta) {
    final next = (page + delta).clamp(0, pages.length - 1);
    pager.animateToPage(
      next,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    revision++;
    debounce?.cancel();
    pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    elevation: 2,
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      bottom: false,
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onVerticalDragEnd: widget.gestures
                ? (d) {
                    if ((d.primaryVelocity ?? 0).abs() > 80)
                      setState(() => expanded = d.primaryVelocity! > 0);
                  }
                : null,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.preview_outlined),
              title: const UiText('معاينة لحظية للكشف'),
              subtitle: UiText(
                pending
                    ? 'جارٍ التحديث…'
                    : pages.isEmpty
                    ? 'نفس ملف التصدير'
                    : '${page + 1} / ${pages.length}',
              ),
              trailing: IconButton(
                tooltip: expanded ? 'تصغير المعاينة' : 'توسيع المعاينة',
                icon: Icon(expanded ? Icons.unfold_less : Icons.unfold_more),
                onPressed: () => setState(() => expanded = !expanded),
              ),
            ),
          ),
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            height: MediaQuery.viewInsetsOf(context).bottom > 0
                ? 72
                : (MediaQuery.sizeOf(context).height * (expanded ? .40 : .22))
                      .clamp(90, 350),
            color: Colors.black12,
            child: pending
                ? const Center(child: CircularProgressIndicator())
                : failure != null
                ? Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: UiText(failure!),
                      onPressed: widget.buildPdf == null
                          ? null
                          : () => setState(schedule),
                    ),
                  )
                : PageView.builder(
                    controller: pager,
                    physics: widget.gestures
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => page = i),
                    itemBuilder: (_, i) => InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      scaleEnabled: widget.gestures,
                      panEnabled: widget.gestures,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.memory(pages[i], fit: BoxFit.contain),
                      ),
                    ),
                  ),
          ),
          SizedBox(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'الصفحة السابقة',
                  onPressed: page > 0 && !pending ? () => move(-1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: widget.buildPdf == null ? null : widget.onOpen,
                  child: const UiText('فتح ومشاركة'),
                ),
                IconButton(
                  tooltip: 'الصفحة التالية',
                  onPressed: page + 1 < pages.length && !pending
                      ? () => move(1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
