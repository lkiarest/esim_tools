import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'models/esim_profile.dart';
import 'repositories/esim_profile_repository.dart';
import 'services/esim_reminder_scheduler.dart';
import 'services/installed_esim_discovery.dart';
import 'services/esim_json_file_transfer.dart';
import 'services/esim_profile_json_codec.dart';

typedef QrCodeScanner = Future<String?> Function(BuildContext context);

class _CountryOption {
  const _CountryOption({
    required this.code,
    required this.flag,
    required this.name,
    required this.dialCode,
  });

  final String code;
  final String flag;
  final String name;
  final String dialCode;

  String get label => '$flag $name';
}

class _DiscoverySyncSummary {
  const _DiscoverySyncSummary({
    required this.added,
    required this.updated,
    required this.active,
    required this.renamed,
  });

  final int added;
  final int updated;
  final int active;
  final int renamed;
}

const List<_CountryOption> _countryOptions = <_CountryOption>[
  _CountryOption(code: 'CN', flag: '🇨🇳', name: '中国大陆', dialCode: '+86'),
  _CountryOption(code: 'HK', flag: '🇭🇰', name: '中国香港', dialCode: '+852'),
  _CountryOption(code: 'MO', flag: '🇲🇴', name: '中国澳门', dialCode: '+853'),
  _CountryOption(code: 'TW', flag: '🇹🇼', name: '中国台湾', dialCode: '+886'),
  _CountryOption(code: 'JP', flag: '🇯🇵', name: '日本', dialCode: '+81'),
  _CountryOption(code: 'KR', flag: '🇰🇷', name: '韩国', dialCode: '+82'),
  _CountryOption(code: 'SG', flag: '🇸🇬', name: '新加坡', dialCode: '+65'),
  _CountryOption(code: 'TH', flag: '🇹🇭', name: '泰国', dialCode: '+66'),
  _CountryOption(code: 'MY', flag: '🇲🇾', name: '马来西亚', dialCode: '+60'),
  _CountryOption(code: 'ID', flag: '🇮🇩', name: '印度尼西亚', dialCode: '+62'),
  _CountryOption(code: 'VN', flag: '🇻🇳', name: '越南', dialCode: '+84'),
  _CountryOption(code: 'PH', flag: '🇵🇭', name: '菲律宾', dialCode: '+63'),
  _CountryOption(code: 'US', flag: '🇺🇸', name: '美国', dialCode: '+1'),
  _CountryOption(code: 'CA', flag: '🇨🇦', name: '加拿大', dialCode: '+1'),
  _CountryOption(code: 'GB', flag: '🇬🇧', name: '英国', dialCode: '+44'),
  _CountryOption(code: 'FR', flag: '🇫🇷', name: '法国', dialCode: '+33'),
  _CountryOption(code: 'DE', flag: '🇩🇪', name: '德国', dialCode: '+49'),
  _CountryOption(code: 'IT', flag: '🇮🇹', name: '意大利', dialCode: '+39'),
  _CountryOption(code: 'ES', flag: '🇪🇸', name: '西班牙', dialCode: '+34'),
  _CountryOption(code: 'AU', flag: '🇦🇺', name: '澳大利亚', dialCode: '+61'),
  _CountryOption(code: 'NZ', flag: '🇳🇿', name: '新西兰', dialCode: '+64'),
  _CountryOption(code: 'AE', flag: '🇦🇪', name: '阿联酋', dialCode: '+971'),
  _CountryOption(code: 'TR', flag: '🇹🇷', name: '土耳其', dialCode: '+90'),
  _CountryOption(code: 'EU', flag: '🇪🇺', name: '欧洲通用', dialCode: ''),
];

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
      title: 'ESIM 管家',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1677FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: const Color(0xFFDAE1EA).withValues(alpha: 0.85),
            ),
          ),
        ),
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
    await _refreshInstalledEsims(showFeedback: false);
  }

  Future<void> _persistProfiles() async {
    await _repository?.saveProfiles(_profiles);
    await _reminderCoordinator.rescheduleAll(_profiles);
  }

  Future<bool> _addProfile(EsimProfile profile) async {
    final sameNameIndex = _findProfileIndexByName(profile.name);
    if (sameNameIndex != -1) {
      _showSnackBar('名称已存在：${_profiles[sameNameIndex].name}');
      return false;
    }
    final duplicate = _findDuplicatePhone(profile);
    if (duplicate != null) {
      _showSnackBar('号码已存在：${duplicate.name}');
      return false;
    }
    setState(() => _profiles.add(profile));
    await _persistProfiles();
    return true;
  }

  Future<bool> _addDiscoveredProfile(EsimProfile profile) async {
    final existingIndex = _findProfileIndexByName(profile.name);
    if (existingIndex != -1) {
      _showSnackBar('已存在同名 SIM：${_profiles[existingIndex].name}');
      return false;
    }
    setState(() => _profiles.add(profile));
    await _persistProfiles();
    return true;
  }

  Future<bool> _replaceProfile(EsimProfile updated) async {
    final index = _profiles.indexWhere((profile) => profile.id == updated.id);
    if (index == -1) return false;
    final sameNameIndex = _findProfileIndexByName(
      updated.name,
      excludingId: updated.id,
    );
    if (sameNameIndex != -1) {
      _showSnackBar('名称已存在：${_profiles[sameNameIndex].name}');
      return false;
    }
    final duplicate = _findDuplicatePhone(updated, excludingId: updated.id);
    if (duplicate != null) {
      _showSnackBar('号码已存在：${duplicate.name}');
      return false;
    }
    setState(() => _profiles[index] = updated);
    await _persistProfiles();
    return true;
  }

  EsimProfile? _findDuplicatePhone(
    EsimProfile candidate, {
    String? excludingId,
  }) {
    final normalized = _normalizedProfilePhone(candidate);
    if (normalized == null) return null;
    for (final profile in _profiles) {
      if (profile.id == excludingId) continue;
      if (_normalizedProfilePhone(profile) == normalized) {
        return profile;
      }
    }
    return null;
  }

  Set<String> _normalizedExistingPhones({String? excludingId}) {
    return _profiles
        .where((profile) => profile.id != excludingId)
        .map(_normalizedProfilePhone)
        .whereType<String>()
        .toSet();
  }

  _DiscoverySyncSummary _mergeDiscoveredProfiles(
    List<DiscoveredEsim> discovered,
  ) {
    final now = DateTime.now();
    var added = 0;
    var updated = 0;
    var active = 0;
    var renamed = 0;

    setState(() {
      for (var index = 0; index < _profiles.length; index += 1) {
        _profiles[index] = _profiles[index].copyWith(isCurrentlyActive: false);
      }

      for (final discoveredProfile in discovered) {
        var discoveredEsim = EsimProfile.fromDiscovered(
          discoveredProfile,
          now: now,
        );
        if (discoveredEsim.isCurrentlyActive) active += 1;

        final index = _findProfileIndexByName(discoveredEsim.name);
        if (index == -1) {
          final uniqueName = _uniqueDiscoveredName(discoveredEsim.name);
          if (uniqueName != discoveredEsim.name) {
            discoveredEsim = discoveredEsim.copyWith(name: uniqueName);
            renamed += 1;
          }
          _profiles.add(discoveredEsim);
          added += 1;
          continue;
        }

        final existing = _profiles[index];
        _profiles[index] = existing.copyWith(
          carrierName: existing.carrierName ?? discoveredEsim.carrierName,
          countryOrRegion:
              existing.countryOrRegion ?? discoveredEsim.countryOrRegion,
          phoneNumber: existing.phoneNumber ?? discoveredEsim.phoneNumber,
          iccid: existing.iccid ?? discoveredEsim.iccid,
          systemIdentifier:
              existing.systemIdentifier ?? discoveredEsim.systemIdentifier,
          status: existing.status == EsimProfileStatus.archived
              ? existing.status
              : EsimProfileStatus.installed,
          isCurrentlyActive: discoveredEsim.isCurrentlyActive,
          updatedAt: now,
        );
        updated += 1;
      }
    });

    return _DiscoverySyncSummary(
      added: added,
      updated: updated,
      active: active,
      renamed: renamed,
    );
  }

  int _findProfileIndexByName(String name, {String? excludingId}) {
    final normalized = _normalizedName(name);
    return _profiles.indexWhere(
      (profile) =>
          profile.id != excludingId &&
          _normalizedName(profile.name) == normalized,
    );
  }

  Set<String> _normalizedExistingNames({String? excludingId}) {
    return _profiles
        .where((profile) => profile.id != excludingId)
        .map((profile) => _normalizedName(profile.name))
        .toSet();
  }

  String _uniqueDiscoveredName(String baseName) {
    final normalizedExistingNames = _profiles
        .map((profile) => _normalizedName(profile.name))
        .toSet();
    return _uniqueNameForSet(baseName, normalizedExistingNames);
  }

  String _uniqueNameForSet(
    String baseName,
    Set<String> normalizedExistingNames,
  ) {
    if (!normalizedExistingNames.contains(_normalizedName(baseName))) {
      return baseName;
    }
    var suffix = 2;
    while (true) {
      final candidate = '$baseName $suffix';
      if (!normalizedExistingNames.contains(_normalizedName(candidate))) {
        return candidate;
      }
      suffix += 1;
    }
  }

  Future<void> _deleteProfile(EsimProfile profile) async {
    setState(() => _profiles.removeWhere((item) => item.id == profile.id));
    await _persistProfiles();
    _showSnackBar('已删除 ${profile.name}');
  }

  Future<void> _replaceAllProfiles(List<EsimProfile> profiles) async {
    final normalizedNames = <String>{};
    final uniqueProfiles = <EsimProfile>[];
    var renamedCount = 0;
    for (final profile in profiles) {
      final uniqueName = _uniqueNameForSet(profile.name, normalizedNames);
      normalizedNames.add(_normalizedName(uniqueName));
      if (uniqueName == profile.name) {
        uniqueProfiles.add(profile);
      } else {
        uniqueProfiles.add(profile.copyWith(name: uniqueName));
        renamedCount += 1;
      }
    }
    setState(() {
      _profiles
        ..clear()
        ..addAll(uniqueProfiles);
    });
    await _persistProfiles();
    if (renamedCount > 0) {
      _showSnackBar('导入内容有 $renamedCount 条重名记录，已自动加序号');
    }
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
          child: SingleChildScrollView(child: SelectableText(json)),
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
    final fileName =
        'esim-profiles-${DateTime.now().toIso8601String().substring(0, 10)}.json';
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

  Future<void> _refreshInstalledEsims({bool showFeedback = true}) async {
    if (_discovering) return;
    if (mounted) setState(() => _discovering = true);
    final result = await widget.discovery.discoverInstalledEsims();
    if (!mounted) return;
    setState(() => _discovering = false);

    if (result.profiles.isEmpty) {
      if (showFeedback) {
        _showSnackBar(result.note ?? '没有读取到当前启用的 SIM/eSIM');
      }
      return;
    }

    final summary = _mergeDiscoveredProfiles(result.profiles);
    await _persistProfiles();

    if (showFeedback) {
      final renamedText = summary.renamed > 0
          ? '，${summary.renamed} 张重名卡已加序号，请修改名称'
          : '';
      _showSnackBar(
        '已刷新：${summary.active} 张使用中，更新 ${summary.updated} 张，新增 ${summary.added} 张$renamedText',
      );
    }
  }

  Future<void> _discoverInstalledEsims() async {
    if (_discovering) return;
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
        importedNames: _profiles.map((profile) => profile.name).toSet(),
        onImport: (discovered) async {
          final profile = EsimProfile.fromDiscovered(discovered);
          final added = await _addDiscoveredProfile(profile);
          if (!added) return;
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
      final added = await _addProfile(profile);
      if (added) _showSnackBar('已添加待安装 eSIM');
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
      final added = await _addProfile(profile);
      if (added) _showSnackBar('已从二维码导入待安装 eSIM');
    } on FormatException {
      _showSnackBar('没有识别到有效的 LPA eSIM 激活码');
    }
  }

  Future<void> _openManualInstalledForm() async {
    final profile = await showModalBottomSheet<EsimProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ManualInstalledForm(
        existingNames: _normalizedExistingNames(),
        existingPhones: _normalizedExistingPhones(),
      ),
    );
    if (profile != null) {
      final added = await _addProfile(profile);
      if (added) _showSnackBar('已手动添加已安装 eSIM');
    }
  }

  Future<void> _openProfileDetail(EsimProfile profile) async {
    final result = await Navigator.of(context).push<_ProfileDetailResult>(
      MaterialPageRoute(
        builder: (context) => _ProfileDetailPage(
          profile: profile,
          existingNames: _normalizedExistingNames(excludingId: profile.id),
          existingPhones: _normalizedExistingPhones(excludingId: profile.id),
        ),
      ),
    );
    if (result == null) return;
    if (result.delete) {
      await _deleteProfile(profile);
    } else if (result.profile != null) {
      final saved = await _replaceProfile(result.profile!);
      if (saved) _showSnackBar('已保存 ${result.profile!.name}');
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
      ..sort((a, b) {
        if (a.isCurrentlyActive != b.isCurrentlyActive) {
          return a.isCurrentlyActive ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ESIM 管家'),
        actions: <Widget>[
          IconButton(
            tooltip: '导入导出',
            onPressed: _showImportExportMenu,
            icon: const Icon(Icons.import_export),
          ),
          IconButton(
            tooltip: '刷新当前使用状态',
            onPressed: _discovering ? null : () => _refreshInstalledEsims(),
            icon: _discovering
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '自动获取已安装 eSIM',
            onPressed: _discovering ? null : _discoverInstalledEsims,
            icon: const Icon(Icons.travel_explore),
          ),
        ],
      ),
      body: _loadingProfiles
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                _HomeSummaryCard(profiles: _profiles, now: now),
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

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({required this.profiles, required this.now});

  final List<EsimProfile> profiles;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final activeCount = profiles
        .where((profile) => profile.isCurrentlyActive)
        .length;
    final reminderCount = profiles
        .where((profile) => profile.attentionMessages(now).isNotEmpty)
        .length;
    final installedCount = profiles
        .where((profile) => profile.status == EsimProfileStatus.installed)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '我的 eSIM',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryMetric(
                  label: '总数',
                  value: profiles.length.toString(),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '已安装',
                  value: installedCount.toString(),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '使用中',
                  value: activeCount.toString(),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '待关注',
                  value: reminderCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
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
    final country = _countryOptionFor(profile.countryOrRegion);
    final statusColor = _statusColor(context, profile.status);
    const activeColor = Color(0xFF0F8B6D);
    final fields = <String>[
      if (profile.countryOrRegion?.isNotEmpty == true)
        _countryText(profile.countryOrRegion),
      if (profile.phoneNumber?.isNotEmpty == true) '号码：${profile.phoneNumber}',
      if (profile.carrierName?.isNotEmpty == true) '运营商：${profile.carrierName}',
    ];
    final attention = profile.attentionMessages(now);

    return Card(
      color: profile.isCurrentlyActive
          ? activeColor.withValues(alpha: 0.08)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: profile.isCurrentlyActive
              ? activeColor.withValues(alpha: 0.45)
              : Colors.transparent,
          width: profile.isCurrentlyActive ? 1.2 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: profile.phoneNumber?.isNotEmpty == true
            ? () => _copyText(context, profile.phoneNumber!, copiedLabel: '号码')
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: country == null
                        ? Icon(
                            Icons.sim_card_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : Text(
                            country.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                  ),
                  if (profile.isCurrentlyActive)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: activeColor,
                          border: Border.all(color: Colors.white, width: 2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (profile.isCurrentlyActive) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '使用中',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusLabel(profile.status),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fields.isEmpty ? '国家、号码、运营商待补充' : fields.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (attention.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        attention.first,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (profile.note?.trim().isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        profile.note!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryResultSheet extends StatelessWidget {
  const _DiscoveryResultSheet({
    required this.result,
    required this.importedNames,
    required this.onImport,
    required this.onManualAdd,
  });

  final EsimDiscoveryResult result;
  final Set<String> importedNames;
  final ValueChanged<DiscoveredEsim> onImport;
  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context) {
    final normalizedImportedNames = importedNames.map(_normalizedName).toSet();
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
            ...result.profiles.map((profile) {
              final name = _discoveredName(profile);
              final imported = normalizedImportedNames.contains(
                _normalizedName(name),
              );
              return Card.outlined(
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(_discoveredSubtitle(profile)),
                  trailing: imported
                      ? const FilledButton(onPressed: null, child: Text('已导入'))
                      : FilledButton(
                          onPressed: () => onImport(profile),
                          child: const Text('导入'),
                        ),
                ),
              );
            }),
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
  const _ManualInstalledForm({
    required this.existingNames,
    required this.existingPhones,
  });

  final Set<String> existingNames;
  final Set<String> existingPhones;

  @override
  State<_ManualInstalledForm> createState() => _ManualInstalledFormState();
}

class _ManualInstalledFormState extends State<_ManualInstalledForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _carrierController = TextEditingController();
  final _phoneController = TextEditingController();
  _CountryOption? _selectedCountry;
  bool _active = false;

  @override
  void dispose() {
    _nameController.dispose();
    _carrierController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final selected = await _showCountryPicker(
      context,
      selectedCode: _selectedCountry?.code,
    );
    if (selected != null) {
      setState(() => _selectedCountry = selected);
    }
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
                    _nameValidator(value, widget.existingNames),
              ),
              TextFormField(
                controller: _carrierController,
                decoration: const InputDecoration(labelText: '运营商，可选'),
              ),
              _PickerField(
                labelText: '国家/地区',
                valueText: _selectedCountry?.label ?? '选择国家/地区',
                leading: _selectedCountry == null
                    ? const Icon(Icons.public)
                    : Text(
                        _selectedCountry!.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                onTap: _pickCountry,
              ),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '号码，可选'),
                validator: (value) => _duplicatePhoneValidator(
                  value,
                  widget.existingPhones,
                  countryOrRegion: _selectedCountry?.code,
                ),
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
                      countryOrRegion: _selectedCountry?.code,
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
                      note: null,
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.labelText,
    required this.valueText,
    required this.onTap,
    this.leading,
  });

  final String labelText;
  final String valueText;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            suffixIcon: const Icon(Icons.expand_more),
          ),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  valueText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
  const _ProfileDetailPage({
    required this.profile,
    required this.existingNames,
    required this.existingPhones,
  });

  final EsimProfile profile;
  final Set<String> existingNames;
  final Set<String> existingPhones;

  @override
  State<_ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<_ProfileDetailPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _carrierController;
  late final TextEditingController _phoneController;
  late final TextEditingController _iccidController;
  late final TextEditingController _serviceIntervalController;
  late final TextEditingController _noteController;
  late EsimProfileStatus _status;
  late bool _active;
  late bool _serviceReminderEnabled;
  late _CountryOption? _selectedCountry;
  late DateTime? _lastServiceDate;
  bool _showActivationCode = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile.name);
    _carrierController = TextEditingController(text: profile.carrierName ?? '');
    _phoneController = TextEditingController(text: profile.phoneNumber ?? '');
    _iccidController = TextEditingController(text: profile.iccid ?? '');
    _serviceIntervalController = TextEditingController(
      text: profile.serviceIntervalMonths?.toString() ?? '6',
    );
    _noteController = TextEditingController(text: profile.note ?? '');
    _status = profile.status;
    _active = profile.isCurrentlyActive;
    _serviceReminderEnabled = profile.serviceReminderEnabled;
    _selectedCountry = _countryOptionFor(profile.countryOrRegion);
    _lastServiceDate = profile.lastServiceDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _carrierController.dispose();
    _phoneController.dispose();
    _iccidController.dispose();
    _serviceIntervalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final selected = await _showCountryPicker(
      context,
      selectedCode: _selectedCountry?.code,
    );
    if (selected != null) {
      setState(() => _selectedCountry = selected);
    }
  }

  Future<void> _pickLastServiceDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _lastServiceDate ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (selected != null) {
      setState(() => _lastServiceDate = selected);
    }
  }

  Future<void> _pickStatus() async {
    final selected = await _showStatusPicker(context, selected: _status);
    if (selected != null) {
      setState(() => _status = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final previewProfile = profile.copyWith(
      lastServiceDate: _lastServiceDate,
      serviceIntervalMonths: _serviceReminderEnabled
          ? _tryParseOptionalInt(_serviceIntervalController.text)
          : null,
      serviceReminderEnabled: _serviceReminderEnabled,
    );
    final nextServiceDate = previewProfile.nextServiceDate;
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
            _copyableTextFormField(
              controller: _nameController,
              labelText: '名称',
              validator: (value) => _nameValidator(value, widget.existingNames),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '如果修改这里的名称，也请同步修改系统设置里的 SIM 卡名称；刷新时会按系统名称识别，名称不一致可能重复出现。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _copyableTextFormField(
              controller: _carrierController,
              labelText: '运营商',
            ),
            _PickerField(
              labelText: '国家/地区',
              valueText:
                  _selectedCountry?.label ??
                  _countryLabel(profile.countryOrRegion),
              leading: const Icon(Icons.public),
              onTap: _pickCountry,
            ),
            _copyableTextFormField(
              controller: _phoneController,
              labelText: '手机号',
              keyboardType: TextInputType.phone,
              validator: (value) => _duplicatePhoneValidator(
                value,
                widget.existingPhones,
                countryOrRegion:
                    _selectedCountry?.code ?? widget.profile.countryOrRegion,
              ),
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
                    Text(
                      '保号提醒',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('适合每隔几个月需要消费、充值或发短信一次来保号的卡。'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('开启保号消费提醒'),
                      value: _serviceReminderEnabled,
                      onChanged: (value) =>
                          setState(() => _serviceReminderEnabled = value),
                    ),
                    if (_serviceReminderEnabled) ...<Widget>[
                      _PickerField(
                        labelText: '最近消费日期',
                        valueText: _lastServiceDate == null
                            ? '选择最近一次消费/充值/短信日期'
                            : _formatDate(_lastServiceDate!),
                        leading: const Icon(Icons.event_outlined),
                        onTap: _pickLastServiceDate,
                      ),
                      if (_lastServiceDate != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _lastServiceDate = null),
                            icon: const Icon(Icons.close),
                            label: const Text('清除日期'),
                          ),
                        ),
                      TextFormField(
                        controller: _serviceIntervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '提醒周期（月）'),
                        validator: (value) {
                          if (!_serviceReminderEnabled) return null;
                          final months = int.tryParse(value?.trim() ?? '');
                          if (months == null || months <= 0) {
                            return '请输入大于 0 的月份数，例如 6';
                          }
                          return null;
                        },
                      ),
                      if (nextServiceDate != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text('下次提醒：${_formatDate(nextServiceDate)} 09:00'),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _PickerField(
              labelText: '状态',
              valueText: _statusLabel(_status),
              leading: Icon(
                _statusIcon(_status),
                color: _statusColor(context, _status),
              ),
              onTap: _pickStatus,
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
                      if (_showActivationCode) ...<Widget>[
                        Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: QrImageView(
                              data: profile.rawActivationCode!,
                              version: QrVersions.auto,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(profile.rawActivationCode!),
                      ] else
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
      countryOrRegion: _selectedCountry?.code ?? original.countryOrRegion,
      phoneNumber: _emptyToNull(_phoneController.text),
      iccid: _emptyToNull(_iccidController.text),
      rawActivationCode: original.rawActivationCode,
      smdpAddress: original.smdpAddress,
      matchingId: original.matchingId,
      lastServiceDate: _lastServiceDate,
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

Future<_CountryOption?> _showCountryPicker(
  BuildContext context, {
  String? selectedCode,
}) {
  return showModalBottomSheet<_CountryOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: _countryOptions.length + 1,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '选择国家/地区',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              );
            }
            final option = _countryOptions[index - 1];
            final selected = option.code == selectedCode;
            return ListTile(
              leading: Text(option.flag, style: const TextStyle(fontSize: 28)),
              title: Text(option.name),
              subtitle: Text(
                option.dialCode.isEmpty
                    ? option.code
                    : '${option.code} · ${option.dialCode}',
              ),
              trailing: selected ? const Icon(Icons.check_circle) : null,
              onTap: () => Navigator.of(context).pop(option),
            );
          },
        ),
      ),
    ),
  );
}

Future<EsimProfileStatus?> _showStatusPicker(
  BuildContext context, {
  required EsimProfileStatus selected,
}) {
  const statuses = <EsimProfileStatus>[
    EsimProfileStatus.notInstalled,
    EsimProfileStatus.installed,
    EsimProfileStatus.archived,
  ];
  return showModalBottomSheet<EsimProfileStatus>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('选择状态', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...statuses.map(
              (status) => ListTile(
                leading: Icon(_statusIcon(status)),
                title: Text(_statusLabel(status)),
                trailing: status == selected
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () => Navigator.of(context).pop(status),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String? _normalizedProfilePhone(EsimProfile profile) {
  return _normalizedPhoneNumber(
    profile.phoneNumber,
    countryOrRegion: profile.countryOrRegion,
  );
}

String _normalizedName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
}

String? _nameValidator(String? value, Set<String> existingNames) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return '请输入名称';
  return existingNames.contains(_normalizedName(trimmed)) ? '名称已存在' : null;
}

String _discoveredName(DiscoveredEsim discovered) {
  if (discovered.displayName?.trim().isNotEmpty == true) {
    return discovered.displayName!.trim();
  }
  if (discovered.carrierName?.trim().isNotEmpty == true) {
    return discovered.carrierName!.trim();
  }
  return '已安装 eSIM';
}

String? _normalizedPhoneNumber(String? phoneNumber, {String? countryOrRegion}) {
  final value = phoneNumber?.trim();
  if (value == null || value.isEmpty) return null;
  final hasInternationalPrefix = value.contains('+') || value.startsWith('00');
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00') && digits.length > 6) {
    digits = digits.substring(2);
  }
  if (digits.length < 5) return null;
  final countryDialCode = _countryDialDigits(countryOrRegion);
  if (countryDialCode != null) {
    return _stripDialCode(digits, countryDialCode);
  }

  final knownDialCodes =
      _countryOptions
          .map((option) => option.dialCode.replaceAll(RegExp(r'\D'), ''))
          .where((code) => code.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  for (final dialCode in knownDialCodes) {
    if (!hasInternationalPrefix && dialCode.length == 1) continue;
    if (digits.startsWith(dialCode) && digits.length - dialCode.length >= 6) {
      return _stripLocalTrunkPrefix(digits.substring(dialCode.length));
    }
  }

  return _stripLocalTrunkPrefix(digits);
}

String? _countryDialDigits(String? countryOrRegion) {
  final option = _countryOptionFor(countryOrRegion);
  final digits = option?.dialCode.replaceAll(RegExp(r'\D'), '');
  return digits == null || digits.isEmpty ? null : digits;
}

String _stripDialCode(String digits, String dialCode) {
  if (digits.startsWith(dialCode) && digits.length - dialCode.length >= 6) {
    return _stripLocalTrunkPrefix(digits.substring(dialCode.length));
  }
  return _stripLocalTrunkPrefix(digits);
}

String _stripLocalTrunkPrefix(String digits) {
  var normalized = digits;
  while (normalized.startsWith('0') && normalized.length > 6) {
    normalized = normalized.substring(1);
  }
  return normalized;
}

String? _duplicatePhoneValidator(
  String? value,
  Set<String> existingPhones, {
  String? countryOrRegion,
}) {
  final normalized = _normalizedPhoneNumber(
    value,
    countryOrRegion: countryOrRegion,
  );
  if (normalized == null) return null;
  return existingPhones.contains(normalized) ? '这个号码已经添加过了' : null;
}

_CountryOption? _countryOptionFor(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final upper = trimmed.toUpperCase();
  for (final option in _countryOptions) {
    if (option.code == upper || option.name == trimmed) return option;
  }
  return null;
}

String _countryLabel(String? value) {
  final option = _countryOptionFor(value);
  if (option != null) return '${option.flag} ${option.name}';
  return value?.trim().isNotEmpty == true ? value!.trim() : '未选择';
}

String _countryText(String? value) {
  final option = _countryOptionFor(value);
  if (option != null) return option.name;
  return value?.trim().isNotEmpty == true ? value!.trim() : '未选择';
}

String _statusLabel(EsimProfileStatus status) {
  return switch (status) {
    EsimProfileStatus.notInstalled => '待安装',
    EsimProfileStatus.installed => '已安装',
    EsimProfileStatus.archived => '已归档',
    EsimProfileStatus.expired => '已过期',
  };
}

IconData _statusIcon(EsimProfileStatus status) {
  return switch (status) {
    EsimProfileStatus.notInstalled => Icons.download_for_offline_outlined,
    EsimProfileStatus.installed => Icons.check_circle_outline,
    EsimProfileStatus.archived => Icons.archive_outlined,
    EsimProfileStatus.expired => Icons.event_busy_outlined,
  };
}

Color _statusColor(BuildContext context, EsimProfileStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    EsimProfileStatus.installed => const Color(0xFF0F8B6D),
    EsimProfileStatus.notInstalled => scheme.primary,
    EsimProfileStatus.archived => scheme.outline,
    EsimProfileStatus.expired => scheme.error,
  };
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _parseOptionalInt(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : int.parse(trimmed);
}

int? _tryParseOptionalInt(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : int.tryParse(trimmed);
}

String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
