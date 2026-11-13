import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/fabric_item.dart';
import '../services/fabric_service.dart';
import '../theme/app_theme.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  static Future<void> showAdminAuthDialogAndNavigate(BuildContext context) async {
    // If session is already unlocked, open Admin Panel directly without asking PIN again
    final isUnlocked = await FabricService.isAdminSessionUnlocked();
    if (isUnlocked && context.mounted) {
      await FabricService.setActiveScreen('admin');
      if (context.mounted) {
        Navigator.of(context).pushNamed('/admin').then((_) {
          FabricService.setActiveScreen('home');
        });
      }
      return;
    }

    final pinController = TextEditingController();
    bool isObscured = true;
    String? errorText;

    if (!context.mounted) return;

    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: AppTheme.primary, size: 26),
              SizedBox(width: 10),
              Text('Admin Authentication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Admin PIN/Password to access fabric inventory and pricing controls.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: isObscured,
                autofocus: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Admin Password / PIN',
                  hintText: 'Enter Admin Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: errorText,
                  suffixIcon: IconButton(
                    icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => isObscured = !isObscured),
                  ),
                ),
                onSubmitted: (_) async {
                  final valid = await FabricService.verifyAdminPassword(pinController.text);
                  if (!ctx.mounted) return;
                  if (valid) {
                    Navigator.of(ctx).pop(true);
                  } else {
                    setState(() => errorText = 'Incorrect Password.');
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final valid = await FabricService.verifyAdminPassword(pinController.text);
                if (!ctx.mounted) return;
                if (valid) {
                  Navigator.of(ctx).pop(true);
                } else {
                  setState(() => errorText = 'Incorrect Password.');
                }
              },
              child: const Text('Unlock Panel'),
            ),
          ],
        ),
      ),
    );

    if (authenticated == true && context.mounted) {
      await FabricService.setActiveScreen('admin');
      if (context.mounted) {
        Navigator.of(context).pushNamed('/admin').then((_) {
          FabricService.setActiveScreen('home');
        });
      }
    }
  }

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<FabricItem> _fabrics = [];
  bool _isLoading = true;
  bool _isUnlocked = false;

  final TextEditingController _lockPinController = TextEditingController();
  bool _lockPinObscured = true;
  String? _lockErrorText;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  @override
  void dispose() {
    _lockPinController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoad() async {
    final unlocked = await FabricService.isAdminSessionUnlocked();
    if (unlocked) {
      await FabricService.setActiveScreen('admin');
    }
    if (!mounted) return;
    setState(() {
      _isUnlocked = unlocked;
    });

    if (unlocked) {
      await _loadFabrics();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unlockFromScreen() async {
    final valid = await FabricService.verifyAdminPassword(_lockPinController.text);
    if (!mounted) return;
    if (valid) {
      setState(() {
        _isUnlocked = true;
        _lockErrorText = null;
      });
      await _loadFabrics();
    } else {
      setState(() {
        _lockErrorText = 'Incorrect Password.';
      });
    }
  }

  Future<void> _loadFabrics() async {
    setState(() => _isLoading = true);
    final list = await FabricService.getAllFabrics();
    if (!mounted) return;
    setState(() {
      _fabrics = list;
      _isLoading = false;
    });
  }

  void _openFabricDialog([FabricItem? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final halfOrderController = TextEditingController(
        text: existing != null ? existing.halfSleeveOrderPrice.toStringAsFixed(0) : '360');
    final fullOrderController = TextEditingController(
        text: existing != null ? existing.fullSleeveOrderPrice.toStringAsFixed(0) : '400');
    final halfCustController = TextEditingController(
        text: existing != null && existing.defaultCustomerHalfPrice > 0
            ? existing.defaultCustomerHalfPrice.toStringAsFixed(0)
            : '450');
    final fullCustController = TextEditingController(
        text: existing != null && existing.defaultCustomerFullPrice > 0
            ? existing.defaultCustomerFullPrice.toStringAsFixed(0)
            : '500');

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Add Jersey Fabric' : 'Edit Fabric & Pricing'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fabric / Jersey Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Leaf Jacquard, China Mesh, Interlock',
                      prefixIcon: Icon(Icons.checkroom),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Fixed Order Prices
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 16, color: Colors.purple),
                            SizedBox(width: 6),
                            Text(
                              'Fixed Order Prices (Supplier Purchase)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: halfOrderController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Half Sleeve (BDT)',
                                  prefixText: 'BDT ',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: fullOrderController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Full Sleeve (BDT)',
                                  prefixText: 'BDT ',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Default Customer Suggested Prices
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sell_outlined, size: 16, color: AppTheme.accent),
                            SizedBox(width: 6),
                            Text(
                              'Suggested Customer Selling Prices',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: halfCustController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Half Sleeve (BDT)',
                                  prefixText: 'BDT ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: fullCustController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Full Sleeve (BDT)',
                                  prefixText: 'BDT ',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final fabric = FabricItem(
                id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                halfSleeveOrderPrice: double.tryParse(halfOrderController.text) ?? 360.0,
                fullSleeveOrderPrice: double.tryParse(fullOrderController.text) ?? 400.0,
                defaultCustomerHalfPrice: double.tryParse(halfCustController.text) ?? 0.0,
                defaultCustomerFullPrice: double.tryParse(fullCustController.text) ?? 0.0,
              );
              await FabricService.saveFabric(fabric);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              await _loadFabrics();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fabric "${fabric.name}" saved!')),
                );
              }
            },
            child: const Text('Save Fabric'),
          ),
        ],
      ),
    );
  }

  void _deleteFabric(FabricItem fabric) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fabric'),
        content: Text('Are you sure you want to delete "${fabric.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FabricService.deleteFabric(fabric.id);
      await _loadFabrics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${fabric.name}"')),
        );
      }
    }
  }

  void _changeAdminPassword() {
    final newPinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Admin Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter new password or PIN for Admin Panel access:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: newPinController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newPinController.text.trim().isNotEmpty) {
                await FabricService.setAdminPassword(newPinController.text.trim());
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Admin password updated successfully!')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        FabricService.setActiveScreen('home');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Home',
            onPressed: () async {
              await FabricService.setActiveScreen('home');
              if (!context.mounted) return;
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings, size: 22),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Admin Panel - Fabric & Pricing',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (_isUnlocked) ...[
              IconButton(
                icon: const Icon(Icons.password),
                tooltip: 'Change Admin PIN',
                onPressed: _changeAdminPassword,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadFabrics,
              ),
              IconButton(
                icon: const Icon(Icons.lock_outline),
                tooltip: 'Lock Admin Panel (Logout)',
                onPressed: () async {
                  await FabricService.logoutAdmin();
                  if (context.mounted) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Admin Panel locked.')),
                    );
                  }
                },
              ),
            ],
          ],
        ),
        floatingActionButton: _isUnlocked
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Add Fabric'),
                onPressed: () => _openFabricDialog(),
              )
            : null,
        body: !_isUnlocked
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Color(0xFFD97706),
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Admin Authentication Required',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter Admin PIN/Password to access wholesale pricing and fabric inventory controls.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _lockPinController,
                            obscureText: _lockPinObscured,
                            autofocus: true,
                            keyboardType: TextInputType.visiblePassword,
                            decoration: InputDecoration(
                              labelText: 'Admin Password / PIN',
                              hintText: 'Enter Admin Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              errorText: _lockErrorText,
                              suffixIcon: IconButton(
                                icon: Icon(_lockPinObscured ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _lockPinObscured = !_lockPinObscured),
                              ),
                            ),
                            onSubmitted: (_) => _unlockFromScreen(),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _unlockFromScreen,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Unlock Admin Panel', style: TextStyle(fontSize: 15)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () async {
                              await FabricService.setActiveScreen('home');
                              if (context.mounted) {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  Navigator.of(context).pushReplacementNamed('/');
                                }
                              }
                            },
                            child: const Text('Back to Home'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _fabrics.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.checkroom_outlined, size: 56, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No fabrics registered yet', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _openFabricDialog(),
                              child: const Text('Add First Fabric'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _fabrics.length,
                        itemBuilder: (context, index) {
                          final item = _fabrics[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.checkroom, color: Colors.purple, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            item.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            tooltip: 'Edit Fabric',
                                            onPressed: () => _openFabricDialog(item),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                                            tooltip: 'Delete Fabric',
                                            onPressed: () => _deleteFabric(item),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Order Invoice Fixed Price
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.purple.shade100),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'ORDER INVOICE (FIXED)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Half: BDT ${item.halfSleeveOrderPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                              ),
                                              Text(
                                                'Full: BDT ${item.fullSleeveOrderPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Customer Invoice Default Price
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade100),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'CUSTOMER (SUGGESTED)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.accent,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Half: BDT ${item.defaultCustomerHalfPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                              ),
                                              Text(
                                                'Full: BDT ${item.defaultCustomerFullPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
