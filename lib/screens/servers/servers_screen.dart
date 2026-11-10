import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../models/server_model.dart';
import '../../providers/server_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/gradient_button.dart';
import 'server_detail_screen.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value.trim().toLowerCase());
    // "My Servers" is filtered here; "Discover" is searched on the backend.
    context.read<ServerProvider>().searchDiscover(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      appBar: AppBar(
        title: const Text('Servers'),
        backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.purple600,
          unselectedLabelColor: isDark ? AppColors.gray500 : AppColors.gray400,
          indicatorColor: AppColors.purple600,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'My Servers'),
            Tab(text: 'Discover'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create server',
            onPressed: () => _showCreateServer(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _MyServersTab(search: _search),
                const _DiscoverTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.gray900,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search servers...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.purple600,
          ),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  void _showCreateServer(BuildContext ctx) {
    showAppSheet<void>(ctx, (_) => const _CreateServerSheet());
  }
}

/// Opens a server I belong to.
void openServer(BuildContext context, ServerModel server) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ServerDetailScreen(server: server)),
  );
}

// ── My Servers Tab ─────────────────────────────────────────────────────────────
class _MyServersTab extends StatelessWidget {
  final String search;

  const _MyServersTab({required this.search});

  @override
  Widget build(BuildContext context) {
    final servers = context.watch<ServerProvider>();
    if (servers.isLoading && servers.joined.isEmpty) {
      return const BrandSpinner();
    }

    final list = servers.joined
        .where((s) => search.isEmpty || s.name.toLowerCase().contains(search))
        .toList();

    return _ServerList(
      servers: list,
      isMember: true,
      onRefresh: servers.loadJoined,
      error: servers.joined.isEmpty ? servers.error : null,
      emptyMessage: search.isEmpty
          ? "You haven't joined any servers yet.\nTap + to create one!"
          : 'No servers match "$search".',
    );
  }
}

// ── Discover Tab ───────────────────────────────────────────────────────────────
class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context) {
    final servers = context.watch<ServerProvider>();
    if (servers.isDiscoverLoading && servers.discover.isEmpty) {
      return const BrandSpinner();
    }
    return _ServerList(
      servers: servers.discover,
      isMember: false,
      onRefresh: servers.loadDiscover,
      error: servers.discover.isEmpty ? servers.error : null,
      emptyMessage: 'No servers available yet.\nBe the first to create one!',
    );
  }
}

class _ServerList extends StatelessWidget {
  final List<ServerModel> servers;
  final bool isMember;
  final Future<void> Function() onRefresh;
  final String emptyMessage;
  final String? error;

  const _ServerList({
    required this.servers,
    required this.isMember,
    required this.onRefresh,
    required this.emptyMessage,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.purple600,
      onRefresh: onRefresh,
      child: servers.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: error != null
                      ? EmptyState(
                          icon: Icons.cloud_off_rounded,
                          message: error!,
                        )
                      : EmptyState(
                          icon: Icons.dns_rounded,
                          message: emptyMessage,
                        ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: servers.length,
              itemBuilder: (_, i) =>
                  _ServerListTile(server: servers[i], isMember: isMember),
            ),
    );
  }
}

// ── Server List Tile ───────────────────────────────────────────────────────────
class _ServerListTile extends StatelessWidget {
  final ServerModel server;
  final bool isMember;

  const _ServerListTile({required this.server, required this.isMember});

  Future<void> _join(BuildContext context) async {
    try {
      await context.read<ServerProvider>().join(server.id);
      if (context.mounted) showInfoSnack(context, 'Joined ${server.name}!');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _confirmJoin(BuildContext context) async {
    final join = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Join ${server.name}?'),
        content: Text(
          server.description.isEmpty
              ? 'Join this server to see its chat, tasks and members.'
              : server.description,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (join == true && context.mounted) await _join(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () =>
          isMember ? openServer(context, server) : _confirmJoin(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.dark800 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDark
              ? Border.all(color: AppColors.dark600, width: 1)
              : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            ServerIcon(server: server, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.gray900,
                    ),
                  ),
                  if (server.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      server.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.gray400 : AppColors.gray500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 13,
                        color: isDark ? AppColors.gray500 : AppColors.gray400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${server.memberCount} member${server.memberCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.gray500 : AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isMember)
              GestureDetector(
                onTap: () => _join(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Join',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.gray500 : AppColors.gray400,
              ),
          ],
        ),
      ),
    );
  }
}

/// The rounded colored square with a server's emoji (or first letter).
class ServerIcon extends StatelessWidget {
  final ServerModel server;
  final double size;

  const ServerIcon({super.key, required this.server, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final color = Color(server.iconColorValue);
    final emoji = server.iconEmoji;
    final hasEmoji = emoji != null && emoji.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Center(
        child: Text(
          hasEmoji ? emoji : initialOf(server.name),
          style: TextStyle(
            fontSize: hasEmoji ? size * 0.5 : size * 0.38,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Create Server Sheet ────────────────────────────────────────────────────────
class _CreateServerSheet extends StatefulWidget {
  const _CreateServerSheet();

  @override
  State<_CreateServerSheet> createState() => _CreateServerSheetState();
}

class _CreateServerSheetState extends State<_CreateServerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _colorValue = kServerColors.first;
  String _emoji = '🌐';
  bool _saving = false;
  String? _error;

  static const _emojis = [
    '🌐',
    '📚',
    '💻',
    '🎯',
    '🚀',
    '🎨',
    '📊',
    '🔬',
    '🏆',
    '💡',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final server = await context.read<ServerProvider>().create(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        iconColorValue: _colorValue,
        iconEmoji: _emoji,
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      openServer(navigator.context, server);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SheetContainer(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Text(
                'Create Server 🌐',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.gray900,
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 16),
              ],
              _fieldLabel('Server Name', isDark),
              const SizedBox(height: 7),
              TextFormField(
                controller: _nameCtrl,
                maxLength: 255,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                decoration: const InputDecoration(
                  hintText: 'My Awesome Server',
                  counterText: '',
                  prefixIcon: Icon(
                    Icons.dns_rounded,
                    color: AppColors.purple600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Description (optional)', isDark),
              const SizedBox(height: 7),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'What is this server about?',
                  prefixIcon: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.gray400,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _fieldLabel('Pick Color', isDark),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: kServerColors.map((c) {
                  final selected = _colorValue == c;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: selected ? 3 : 0,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Color(c).withAlpha(100),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _fieldLabel('Pick Emoji', isDark),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojis.map((e) {
                  final selected = _emoji == e;
                  return GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.purple600.withAlpha(20)
                            : (isDark ? AppColors.dark700 : AppColors.gray50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.purple600
                              : (isDark
                                    ? AppColors.dark500
                                    : AppColors.gray200),
                          width: selected ? 2 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: _saving ? 'Creating...' : 'Create Server',
                icon: Icons.rocket_launch_rounded,
                onTap: _saving ? null : _create,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, bool isDark) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: isDark ? AppColors.gray200 : AppColors.gray700,
    ),
  );
}
