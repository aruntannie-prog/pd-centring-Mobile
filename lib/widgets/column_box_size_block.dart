import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bill.dart';
import '../data/rate_card.dart';

class ColumnBoxSizeBlock extends StatefulWidget {
  final String sizeKey;
  final void Function(ColumnSizeBlock) onChanged;
  final void Function() onRemove;

  const ColumnBoxSizeBlock({
    super.key,
    required this.sizeKey,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<ColumnBoxSizeBlock> createState() => _ColumnBoxSizeBlockState();
}

class _ColumnBoxSizeBlockState extends State<ColumnBoxSizeBlock> {
  final Set<int> _addedHeights = {};
  final Map<int, ({TextEditingController qty, TextEditingController rate})> _heightControllers = {};
  bool _shoeAdded = false;
  TextEditingController? _shoeQtyCtrl;
  TextEditingController? _shoeRateCtrl;

  @override
  void dispose() {
    for (final c in _heightControllers.values) {
      c.qty.dispose();
      c.rate.dispose();
    }
    _shoeQtyCtrl?.dispose();
    _shoeRateCtrl?.dispose();
    super.dispose();
  }

  void _notify() {
    // Sort heights descending as they update
    final sortedHeights = _addedHeights.toList()..sort((a, b) => b.compareTo(a));

    final heightRows = sortedHeights.map((ht) {
      final c = _heightControllers[ht]!;
      return ColumnHeightRow(
        heightFt: ht,
        qty: int.tryParse(c.qty.text) ?? 0,
        rate: double.tryParse(c.rate.text) ?? 0.0,
      );
    }).toList();

    final shoe = _shoeAdded
        ? ColumnShoeRow(
            qty: int.tryParse(_shoeQtyCtrl!.text) ?? 0,
            rate: double.tryParse(_shoeRateCtrl!.text) ?? 0.0,
          )
        : null;

    widget.onChanged(ColumnSizeBlock(
      sizeKey: widget.sizeKey,
      heightRows: heightRows,
      shoe: shoe,
    ));
    setState(() {}); // trigger rebuild to compute amounts
  }

  void _addHeight(int ht) {
    if (_addedHeights.contains(ht)) return;
    
    final qtyCtrl = TextEditingController()..addListener(_notify);
    final rateCtrl = TextEditingController()..addListener(_notify);
    
    setState(() {
      _addedHeights.add(ht);
      _heightControllers[ht] = (qty: qtyCtrl, rate: rateCtrl);
    });
    _notify();
  }

  void _removeHeight(int ht) {
    _heightControllers[ht]!.qty.dispose();
    _heightControllers[ht]!.rate.dispose();
    setState(() {
      _addedHeights.remove(ht);
      _heightControllers.remove(ht);
    });
    _notify();
  }

  void _addShoe() {
    if (_shoeAdded) return;
    
    _shoeQtyCtrl = TextEditingController()..addListener(_notify);
    _shoeRateCtrl = TextEditingController()..addListener(_notify);
    
    setState(() {
      _shoeAdded = true;
    });
    _notify();
  }

  void _removeShoe() {
    _shoeQtyCtrl?.dispose();
    _shoeRateCtrl?.dispose();
    _shoeQtyCtrl = null;
    _shoeRateCtrl = null;
    setState(() {
      _shoeAdded = false;
    });
    _notify();
  }

  Widget _buildField(TextEditingController ctrl, String hint, {bool isInt = true}) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: isInt 
            ? [FilteringTextInputFormatter.digitsOnly] 
            : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: 21" x 21" [Remove]
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  RateCard.label(widget.sizeKey),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: widget.onRemove,
                  tooltip: 'Remove size',
                ),
              ],
            ),
            const Divider(),
            
            // Add rows section
            const Text('Add rows:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...RateCard.heights.map((ht) {
                  final added = _addedHeights.contains(ht);
                  return ActionChip(
                    label: Text('${ht}ft'),
                    backgroundColor: added ? Colors.grey.shade200 : Theme.of(context).primaryColor.withOpacity(0.1),
                    onPressed: added ? null : () => _addHeight(ht),
                  );
                }).toList(),
                
                // Divider before shoe
                Container(width: 1, height: 24, color: Colors.grey.shade400, margin: const EdgeInsets.symmetric(horizontal: 4)),
                
                ActionChip(
                  label: const Text('Shoe'),
                  backgroundColor: _shoeAdded ? Colors.grey.shade200 : Colors.orange.withOpacity(0.1),
                  onPressed: _shoeAdded ? null : _addShoe,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (_addedHeights.isNotEmpty || _shoeAdded) ...[
              // Column headers
              Row(
                children: [
                  const SizedBox(width: 50, child: Text('Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 60, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Rate (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 60, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 40), // close btn space
                ],
              ),
              const Divider(),
              
              // Height Rows
              ...(_addedHeights.toList()..sort((a,b) => b.compareTo(a))).map((ht) {
                final c = _heightControllers[ht]!;
                final qtyStr = c.qty.text;
                final rateStr = c.rate.text;
                final qty = int.tryParse(qtyStr) ?? 0;
                final rate = double.tryParse(rateStr) ?? 0.0;
                final amt = qty * rate;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 50, child: Text('${ht}ft', style: const TextStyle(fontWeight: FontWeight.bold))),
                      _buildField(c.qty, 'Qty'),
                      const SizedBox(width: 16),
                      _buildField(c.rate, 'Rate', isInt: false),
                      Expanded(
                        child: Text(
                          amt > 0 ? '₹${amt.toStringAsFixed(0)}' : '—',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeHeight(ht),
                        ),
                      )
                    ],
                  ),
                );
              }).toList(),
              
              // Shoe Row
              if (_shoeAdded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 50, child: Text('Shoe', style: TextStyle(fontWeight: FontWeight.bold))),
                      _buildField(_shoeQtyCtrl!, 'Qty'),
                      const SizedBox(width: 16),
                      _buildField(_shoeRateCtrl!, 'Rate', isInt: false),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final qty = int.tryParse(_shoeQtyCtrl!.text) ?? 0;
                            final rate = double.tryParse(_shoeRateCtrl!.text) ?? 0.0;
                            final amt = qty * rate;
                            return Text(
                              amt > 0 ? '₹${amt.toStringAsFixed(0)}' : '—',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            );
                          }
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _removeShoe,
                        ),
                      )
                    ],
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }
}
