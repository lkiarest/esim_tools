import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'models/esim_profile.dart';
import 'repositories/esim_profile_repository.dart';
import 'services/esim_reminder_scheduler.dart';
import 'services/installed_esim_discovery.dart';
import 'services/esim_json_file_transfer.dart';
import 'services/esim_profile_json_codec.dart';

typedef QrCodeScanner = Future<String?> Function(BuildContext context);

void main() {
  runApp(const EsimToolApp());
}

class EsimToolApp extends StatelessWidget {
  const EsimToolApp({
    super.key,
    this.discovery = const InstalledEsimDiscovery(),
    this.qrCodeScanner = _scanQrCodeWithCamera,
    this.sensitiveStore,
    this.reminderNotifier,
  });

  final InstalledEsimDiscovery discovery;
  final QrCodeScanner qrCodeScanner;
  final SensitiveProfileStore? sensitiveStore;
  final EsimReminderNotifier? reminderNotifier;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSIM 管家',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3867D6)),
        useMaterial3: true,
      ),
      home: EsimHomePage(
        discovery: discovery,
        qrCodeScanner: qrCodeScanner,
        sensitiveStore: sensitiveStore,
        reminderNotifier: reminderNotifier,
      ),
    );
  }
}

class EsimHomePage extends StatefulWidget {
  const EsimHomePage({
    super.key,
    required this.discovery,
    required this.qrCodeScanner,
    this.sensitiveStore,
    this.reminderNotifier,
  });

  final InstalledEsimDiscovery discovery;
  final QrCodeScanner qrCodeScanner;
  final SensitiveProfileStore? sensitiveStore;
  final EsimReminderNotifier? reminderNotifier;

  @override
  State<EsimHomePage> createState() => _EsimHomePageState();
}

class _EsimHomePageState extends State<EsimHomePage> {
  final List<EsimProfile> _profiles = <EsimProfile>[];
  final EsimJsonFileTransfer _jsonFileTransfer = const EsimJsonFileTransfer();
  EsimProfileRepository? _repository;
  late final EsimReminderCoordinator _reminderCoordinator;
  bool _discovering = false;
  bool _loadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _reminderCoordinator = EsimReminderCoordinator(
      notifier: widget.reminderNotifier ?? FlutterLocalEsimReminderNotifier(),
    );
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final repository = await EsimProfileRepository.create(
      sensitiveStore: widget.sensitiveStore,
    );
    final profiles = await repository.loadProfiles();
    await _reminderCoordinator.rescheduleAll(profiles);
    if (!mounted) return;
    setState(() {
      _repository = repository;
      _profiles
        ..clear()
        ..addAll(profiles);
      _loadingProfiles = false;
    });
  }

  Future<void> _persistProfiles() async {
    await _repository?.saveProfiles(_profiles);
    await _reminderCoordinator.rescheduleAll(_profiles);
  }

  Future<void> _addProfile(EsimProfile profile) async {
    setState(() => _profiles.add(profile));
    await _persistProfiles();
  }

  Future<void> _replaceProfile(EsimProfile updated) async {
    final index = _profiles.indexWhere((profile) => profile.id == updated.id);
    if (index == -1) return;
    setState(() => _profiles[index] = updated);
    await _persistProfiles();
  }

  Future<void> _deleteProfile(EsimProfile profile) async {
    setState(() => _profiles.removeWhere((item) => item.id == profile.id));
    await _persistProfiles();
    _showSnackBar('已删除 ${profile.name}');
  }

  Future<void> _replaceAllProfiles(List<EsimProfile> profiles) async {
    setState(() {
      _profiles
        ..clear()
        ..addAll(profiles);
    });
    await _persistProfiles();
  }

  String _profilesAsJson() => EsimProfileJsonCodec.encode(_profiles);

  Future<void> _showImportExportMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('查看/复制 JSON 字符串'),
              subtitle: const Text('适合直接复制、粘贴到编辑器批量修改'),
              onTap: () {
                Navigator.pop(context);
                _showJsonExportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.paste_outlined),
              title: const Text('从 JSON 字符串导入'),
              subtitle: const Text('粘贴编辑后的 JSON，替换整个列表'),
              onTap: () {
                Navigator.pop(context);
                _showJsonImportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('导出 JSON 文件'),
              subtitle: const Text('保存为 .json 文件，方便在电脑上编辑'),
              onTap: () {
                Navigator.pop(context);
                _exportJsonFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('导入 JSON 文件'),
              subtitle: const Text('选择 .json 文件并替换整个列表'),
              onTap: () {
                Navigator.pop(context);
                _importJsonFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showJsonExportDialog() async {
    final json = _profilesAsJson();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('整表 JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(json),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              _showSnackBar('已复制 JSON 字符串');
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制 JSON'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJsonImportDialog({String? initialJson}) async {
    final controller = TextEditingController(text: initialJson ?? '');
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('导入整表 JSON'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              minLines: 8,
              maxLines: 16,
              decoration: InputDecoration(
                labelText: '粘贴 JSON 字符串',
                helperText: '支持导出的对象格式，也支持直接粘贴 profiles 数组。导入会替换整个列表。',
                errorText: errorText,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final imported = EsimProfileJsonCodec.decode(controller.text);
                  await _replaceAllProfiles(imported);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  _showSnackBar('已导入 ${imported.length} 条记录');
                } on FormatException catch (error) {
                  setDialogState(() => errorText = error.message);
                }
              },
              child: const Text('替换整个列表'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportJsonFile() async {
    final fileName = 'esim-profiles-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final exported = await _jsonFileTransfer.exportJsonFile(
      _profilesAsJson(),
      fileName: fileName,
    );
    _showSnackBar(exported ? '已导出 JSON 文件' : '当前平台未完成文件导出，可先复制 JSON 字符串');
  }

  Future<void> _importJsonFile() async {
    final json = await _jsonFileTransfer.importJsonFile();
    if (json == null || json.trim().isEmpty) {
      _showSnackBar('没有选择 JSON 文件');
      return;
    }
    await _showJsonImportDialog(initialJson: json);
  }

  Future<void> _discoverInstalledEsims() async {
    setState(() => _discovering = true);
    final result = await widget.discovery.discoverInstalledEsims();
    if (!mounted) return;
    setState(() {
      _discovering = false;
    });

    if (result.profiles.isEmpty) {
      await _showManualFallback(result);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DiscoveryResultSheet(
        result: result,
        onImport: (discovered) async {
          final profile = EsimProfile.fromDiscovered(discovered);
          await _addProfile(profile);
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _showSnackBar('已导入 ${profile.name}，记得补充号码和保号消费周期。');
        },
        onManualAdd: () {
          Navigator.of(context).pop();
          _openManualInstalledForm();
        },
      ),
    );
  }

  Future<void> _showManualFallback(EsimDiscoveryResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('没有自动获取到 eSIM'),
        content: Text(
          result.note ?? '可能是系统限制、权限未授权、设备不支持，或已安装 eSIM 处于停用状态。你仍然可以手动添加。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openManualInstalledForm();
            },
            child: const Text('手动添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _openActivationCodeForm() async {
    final profile = await showModalBottomSheet<EsimProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ActivationCodeForm(),
    );
    if (profile != null) {
      await _addProfile(profile);
      _showSnackBar('已添加待安装 eSIM');
    }
  }

  Future<void> _scanQrCode() async {
    final scanned = await widget.qrCodeScanner(context);
    if (!mounted || scanned == null) return;

    try {
      final profile = EsimProfile.fromActivationCode(
        scanned,
        name: '二维码 eSIM',
      ).copyWith(source: EsimProfileSource.qrCode);
      await _addProfile(profile);
      _showSnackBar('已从二维码导入待安装 eSIM');
    } on FormatException {
      _showSnackBar('没有识别到有效的 LPA eSIM 激活码');
    }
  }

  Future<void> _openManualInstalledForm() async {
    final profile = await showModalBottomSheet<EsimProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ManualInstalledForm(),
    );
    if (profile != null) {
      await _addProfile(profile);
      _showSnackBar('已手动添加已安装 eSIM');
    }
  }

  Future<void> _openProfileDetail(EsimProfile profile) async {
    final result = await Navigator.of(context).push<_ProfileDetailResult>(
      MaterialPageRoute(
        builder: (context) => _ProfileDetailPage(profile: profile),
      ),
    );
    if (result == null) return;
    if (result.delete) {
      await _deleteProfile(profile);
    } else if (result.profile != null) {
      await _replaceProfile(result.profile!);
      _showSnackBar('已保存 ${result.profile!.name}');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final profiles = _profiles.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('eSIM 管家'),
        actions: <Widget>[
          IconButton(
            tooltip: '导入导出',
            onPressed: _showImportExportMenu,
            icon: const Icon(Icons.import_export),
          ),
          IconButton(
            tooltip: '自动获取已安装 eSIM',
            onPressed: _discovering ? null : _discoverInstalledEsims,
            icon: _discovering
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore),
          ),
        ],
      ),
      body: _loadingProfiles
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                _AttentionSection(
                  profiles: _profiles,
                  now: now,
                  onTap: _openProfileDetail,
                ),
                _ProfileSection(
                  title: 'SIM 列表',
                  emptyText: '暂无 SIM/eSIM 记录，点右下角添加或自动获取。',
                  profiles: profiles,
                  now: now,
                  onTap: _openProfileDetail,
                  onDelete: _confirmDeleteFromList,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context),
        icon: const Icon(Icons.add),
        label: const Text('添加'),
      ),
    );
  }

  Future<void> _confirmDeleteFromList(EsimProfile profile) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${profile.name}？'),
        content: const Text('这里只删除 App 内记录，不会删除系统中已安装的 eSIM。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await _deleteProfile(profile);
    }
  }

  Future<void> _showAddMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('扫描二维码'),
              subtitle: const Text('打开相机扫描 LPA eSIM 二维码'),
              onTap: () {
                Navigator.pop(context);
                _scanQrCode();
              },
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('输入激活码'),
              subtitle: const Text('保存待安装的 LPA eSIM'),
              onTap: () {
                Navigator.pop(context);
                _openActivationCodeForm();
              },
            ),
            ListTile(
              leading: const Icon(Icons.travel_explore),
              title: const Text('自动获取已安装 eSIM'),
              subtitle: const Text('优先从系统读取，失败后手动添加'),
              onTap: () {
                Navigator.pop(context);
                _discoverInstalledEsims();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('手动添加已安装 eSIM'),
              subtitle: const Text('填写运营商、国家/地区、号码和保号周期'),
              onTap: () {
                Navigator.pop(context);
                _openManualInstalledForm();
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _scanQrCodeWithCamera(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (context) => const _QrScannerPage()),
  );
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描 eSIM 二维码')),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final rawValue = capture.barcodes
                  .map((barcode) => barcode.rawValue)
                  .whereType<String>()
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .firstOrNull;
              if (rawValue == null) return;
              _handled = true;
              Navigator.of(context).pop(rawValue);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Card.filled(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '请对准运营商提供的 LPA eSIM 二维码',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('扫描结果只会保存在本机；如果二维码无法识别，可以返回后选择“输入激活码”。'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionSection extends StatelessWidget {
  const _AttentionSection({
    required this.profiles,
    required this.now,
    required this.onTap,
  });

  final List<EsimProfile> profiles;
  final DateTime now;
  final ValueChanged<EsimProfile> onTap;

  @override
  Widget build(BuildContext context) {
    final attentionProfiles =
        profiles
            .where((profile) => profile.attentionMessages(now).isNotEmpty)
            .toList()
          ..sort((a, b) {
            final aDays = a.daysUntilService(now) ?? 9999;
            final bDays = b.daysUntilService(now) ?? 9999;
            return aDays.compareTo(bDays);
          });
    if (attentionProfiles.isEmpty) return const SizedBox.shrink();

    return Card.filled(
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 8),
                Text('需要关注', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...attentionProfiles
                .take(3)
                .map(
                  (profile) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(profile.name),
                    subtitle: Text(profile.attentionMessages(now).join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onTap(profile),
                  ),
                ),
            if (attentionProfiles.length > 3)
              Text(
                '还有 ${attentionProfiles.length - 3} 张卡需要检查',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.emptyText,
    required this.profiles,
    required this.now,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String emptyText;
  final List<EsimProfile> profiles;
  final DateTime now;
  final ValueChanged<EsimProfile> onTap;
  final ValueChanged<EsimProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (profiles.isEmpty)
            Card.outlined(
              child: ListTile(
                title: Text(emptyText),
                leading: const Icon(Icons.sim_card_outlined),
              ),
            )
          else
            ...profiles.map(
              (profile) => _ProfileTile(
                profile: profile,
                now: now,
                onTap: () => onTap(profile),
                onDelete: () => onDelete(profile),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.now,
    required this.onTap,
    required this.onDelete,
  });

  final EsimProfile profile;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fields = <String>[
      if (profile.countryOrRegion?.isNotEmpty == true)
        '国家：${profile.countryOrRegion}',
      if (profile.phoneNumber?.isNotEmpty == true) '号码：${profile.phoneNumber}',
      if (profile.carrierName?.isNotEmpty == true) '运营商：${profile.carrierName}',
    ];

    return Card(
      child: ListTile(
        onTap: onTap,
        onLongPress: profile.phoneNumber?.isNotEmpty == true
            ? () => _copyText(context, profile.phoneNumber!, copiedLabel: '号码')
            : null,
        leading: const Icon(Icons.sim_card_outlined),
        title: Text(profile.name),
        subtitle: fields.isEmpty
            ? const Text('国家、号码、运营商待补充')
            : Text(
                fields.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: '删除',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryResultSheet extends StatelessWidget {
  const _DiscoveryResultSheet({
    required this.result,
    required this.onImport,
    required this.onManualAdd,
  });

  final EsimDiscoveryResult result;
  final ValueChanged<DiscoveredEsim> onImport;
  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '发现 ${result.profiles.length} 个可见蜂窝套餐',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('自动发现的信息可能不完整，导入后请补充号码和保号消费周期。'),
            const SizedBox(height: 12),
            ...result.profiles.map(
              (profile) => Card.outlined(
                child: ListTile(
                  title: Text(
                    profile.displayName ?? profile.carrierName ?? '未知套餐',
                  ),
                  subtitle: Text(_discoveredSubtitle(profile)),
                  trailing: FilledButton(
                    onPressed: () => onImport(profile),
                    child: const Text('导入'),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onManualAdd,
                icon: const Icon(Icons.edit_note),
                label: const Text('手动添加'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _discoveredSubtitle(DiscoveredEsim profile) {
  final confidence = switch (profile.confidence) {
    DiscoveryConfidence.high => '高',
    DiscoveryConfidence.medium => '中',
    DiscoveryConfidence.low => '低',
    DiscoveryConfidence.unknown => '未知',
  };
  return <String>[
    if (profile.carrierName != null) '运营商：${profile.carrierName}',
    if (profile.countryIso != null) '国家：${profile.countryIso!.toUpperCase()}',
    if (profile.mobileCountryCode != null && profile.mobileNetworkCode != null)
      'MCC/MNC：${profile.mobileCountryCode}/${profile.mobileNetworkCode}',
    profile.isActive == false ? '状态：未启用/系统可见' : '状态：当前启用',
    '可信度：$confidence',
  ].join('\n');
}

class _ActivationCodeForm extends StatefulWidget {
  const _ActivationCodeForm();

  @override
  State<_ActivationCodeForm> createState() => _ActivationCodeFormState();
}

class _ActivationCodeFormState extends State<_ActivationCodeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '输入 eSIM 激活码',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称，例如 日本 7 天卡'),
              ),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'LPA 激活码'),
                minLines: 2,
                maxLines: 4,
                validator: (value) {
                  try {
                    EsimProfile.fromActivationCode(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop(
                      EsimProfile.fromActivationCode(
                        _codeController.text,
                        name: _nameController.text,
                      ),
                    );
                  }
                },
                child: const Text('保存待安装 eSIM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualInstalledForm extends StatefulWidget {
  const _ManualInstalledForm();

  @override
  State<_ManualInstalledForm> createState() => _ManualInstalledFormState();
}

class _ManualInstalledFormState extends State<_ManualInstalledForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _carrierController = TextEditingController();
  final _countryController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _active = false;

  @override
  void dispose() {
    _nameController.dispose();
    _carrierController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '手动添加已安装 eSIM',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入名称' : null,
              ),
              TextFormField(
                controller: _carrierController,
                decoration: const InputDecoration(labelText: '运营商，可选'),
              ),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(labelText: '国家/地区，可选'),
              ),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '号码，可选'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('当前正在使用'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  final now = DateTime.now();
                  Navigator.of(context).pop(
                    EsimProfile(
                      id: 'manual-${now.microsecondsSinceEpoch}',
                      name: _nameController.text.trim(),
                      carrierName: _emptyToNull(_carrierController.text),
                      countryOrRegion: _emptyToNull(_countryController.text),
                      phoneNumber: _emptyToNull(_phoneController.text),
                      iccid: null,
                      rawActivationCode: null,
                      smdpAddress: null,
                      matchingId: null,
                      lastServiceDate: null,
                      serviceIntervalMonths: 6,
                      serviceReminderEnabled: false,
                      status: EsimProfileStatus.installed,
                      source: EsimProfileSource.manualInstalled,
                      isCurrentlyActive: _active,
                      note: '手动添加，可补充最近消费日期和保号周期。',
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
                },
                child: const Text('保存已安装 eSIM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailResult {
  const _ProfileDetailResult.save(this.profile) : delete = false;
  const _ProfileDetailResult.delete() : profile = null, delete = true;

  final EsimProfile? profile;
  final bool delete;
}

class _ProfileDetailPage extends StatefulWidget {
  const _ProfileDetailPage({required this.profile});

  final EsimProfile profile;

  @override
  State<_ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<_ProfileDetailPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _carrierController;
  late final TextEditingController _countryController;
  late final TextEditingController _phoneController;
  late final TextEditingController _iccidController;
  late final TextEditingController _lastServiceDateController;
  late final TextEditingController _serviceIntervalController;
  late final TextEditingController _noteController;
  late EsimProfileStatus _status;
  late bool _active;
  late bool _serviceReminderEnabled;
  bool _showActivationCode = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile.name);
    _carrierController = TextEditingController(text: profile.carrierName ?? '');
    _countryController = TextEditingController(
      text: profile.countryOrRegion ?? '',
    );
    _phoneController = TextEditingController(text: profile.phoneNumber ?? '');
    _iccidController = TextEditingController(text: profile.iccid ?? '');
    _lastServiceDateController = TextEditingController(
      text: profile.lastServiceDate == null ? '' : _formatDate(profile.lastServiceDate!),
    );
    _serviceIntervalController = TextEditingController(
      text: profile.serviceIntervalMonths?.toString() ?? '6',
    );
    _noteController = TextEditingController(text: profile.note ?? '');
    _status = profile.status;
    _active = profile.isCurrentlyActive;
    _serviceReminderEnabled = profile.serviceReminderEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _carrierController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _iccidController.dispose();
    _lastServiceDateController.dispose();
    _serviceIntervalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final nextServiceDate = profile.nextServiceDate;
    return Scaffold(
      appBar: AppBar(
        title: const Text('eSIM 详情'),
        actions: <Widget>[
          IconButton(
            tooltip: '删除',
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('保存修改'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: <Widget>[
            Card.filled(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(_sourceLabel(profile.source)),
                subtitle: Text(
                  profile.rawActivationCode == null
                      ? '只保留保号常用信息：名称、运营商、国家/地区、号码、ICCID 和消费提醒。'
                      : '激活码、Matching ID、ICCID、手机号会使用系统安全存储保护，并默认隐藏显示。',
                ),
              ),
            ),
            _copyableTextFormField(
              controller: _nameController,
              labelText: '名称',
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入名称' : null,
            ),
            _copyableTextFormField(
              controller: _carrierController,
              labelText: '运营商',
            ),
            _copyableTextFormField(
              controller: _countryController,
              labelText: '国家/地区',
            ),
            _copyableTextFormField(
              controller: _phoneController,
              labelText: '手机号',
              keyboardType: TextInputType.phone,
            ),
            _copyableTextFormField(
              controller: _iccidController,
              labelText: 'ICCID',
            ),
            const SizedBox(height: 12),
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('保号提醒', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('适合每隔几个月需要消费、充值或发短信一次来保号的卡。'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('开启保号消费提醒'),
                      value: _serviceReminderEnabled,
                      onChanged: (value) => setState(() => _serviceReminderEnabled = value),
                    ),
                    _copyableTextFormField(
                      controller: _lastServiceDateController,
                      labelText: '最近消费日期 YYYY-MM-DD',
                      keyboardType: TextInputType.datetime,
                      validator: _optionalDateValidator,
                    ),
                    TextFormField(
                      controller: _serviceIntervalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '提醒周期（月）'),
                      validator: (value) {
                        if (!_serviceReminderEnabled) return null;
                        final months = int.tryParse(value?.trim() ?? '');
                        if (months == null || months <= 0) return '请输入大于 0 的月份数，例如 6';
                        return null;
                      },
                    ),
                    if (nextServiceDate != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text('下次提醒：${_formatDate(nextServiceDate)} 09:00'),
                    ],
                  ],
                ),
              ),
            ),
            DropdownButtonFormField<EsimProfileStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: '状态'),
              items: const <DropdownMenuItem<EsimProfileStatus>>[
                DropdownMenuItem(
                  value: EsimProfileStatus.notInstalled,
                  child: Text('待安装'),
                ),
                DropdownMenuItem(
                  value: EsimProfileStatus.installed,
                  child: Text('已安装'),
                ),
                DropdownMenuItem(
                  value: EsimProfileStatus.archived,
                  child: Text('已归档'),
                ),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('当前正在使用'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            _copyableTextFormField(
              controller: _noteController,
              labelText: '备注',
              minLines: 2,
              maxLines: 4,
            ),
            if (profile.rawActivationCode != null) ...<Widget>[
              const SizedBox(height: 16),
              Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '激活码',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_showActivationCode)
                        SelectableText(profile.rawActivationCode!)
                      else
                        const Text('•••• •••• •••• ••••（已隐藏，避免旁人看到或截图泄露）'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: () => setState(
                              () => _showActivationCode = !_showActivationCode,
                            ),
                            icon: Icon(
                              _showActivationCode
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            label: Text(
                              _showActivationCode ? '隐藏激活码' : '显示激活码',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _copyText(
                              context,
                              profile.rawActivationCode!,
                              copiedLabel: '激活码',
                            ),
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('复制激活码'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _copyableTextFormField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? minLines,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _copyableDecoration(controller, labelText),
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
    );
  }

  InputDecoration _copyableDecoration(
    TextEditingController controller,
    String labelText,
  ) {
    return InputDecoration(
      labelText: labelText,
      suffixIcon: IconButton(
        tooltip: '复制$labelText',
        onPressed: () =>
            _copyText(context, controller.text, copiedLabel: labelText),
        icon: const Icon(Icons.copy_outlined),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这张 eSIM 记录？'),
        content: const Text('这里只删除 App 内记录，不会删除系统中已安装的 eSIM。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && mounted) {
      Navigator.of(context).pop(const _ProfileDetailResult.delete());
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final original = widget.profile;
    final updated = EsimProfile(
      id: original.id,
      name: _nameController.text.trim(),
      carrierName: _emptyToNull(_carrierController.text),
      countryOrRegion: _emptyToNull(_countryController.text),
      phoneNumber: _emptyToNull(_phoneController.text),
      iccid: _emptyToNull(_iccidController.text),
      rawActivationCode: original.rawActivationCode,
      smdpAddress: original.smdpAddress,
      matchingId: original.matchingId,
      lastServiceDate: _parseOptionalDate(_lastServiceDateController.text),
      serviceIntervalMonths: _serviceReminderEnabled
          ? _parseOptionalInt(_serviceIntervalController.text)
          : null,
      serviceReminderEnabled: _serviceReminderEnabled,
      status: _status,
      source: original.source,
      isCurrentlyActive: _active,
      note: _emptyToNull(_noteController.text),
      createdAt: original.createdAt,
      updatedAt: now,
    );
    Navigator.of(context).pop(_ProfileDetailResult.save(updated));
  }
}

Future<void> _copyText(
  BuildContext context,
  String value, {
  required String copiedLabel,
}) async {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$copiedLabel 为空，无法复制')));
    return;
  }
  await Clipboard.setData(ClipboardData(text: trimmed));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('已复制$copiedLabel')));
}

String? _optionalDateValidator(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return _parseOptionalDate(value) == null ? '格式应为 YYYY-MM-DD' : null;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _parseOptionalInt(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : int.parse(trimmed);
}

DateTime? _parseOptionalDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime.tryParse(
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
  );
}

String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _sourceLabel(EsimProfileSource source) {
  return switch (source) {
    EsimProfileSource.qrCode => '二维码导入',
    EsimProfileSource.activationCode => '激活码导入',
    EsimProfileSource.manualInstalled => '手动添加已安装 eSIM',
    EsimProfileSource.systemDiscovered => '系统自动发现',
  };
}
