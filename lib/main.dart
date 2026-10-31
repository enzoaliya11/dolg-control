import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DebtApp());
}

class DebtApp extends StatelessWidget {
  const DebtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ДОЛГ КОНТРОЛ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B57),
        ),
        useMaterial3: true,
      ),
      home: const DebtHome(),
    );
  }
}

class DebtHome extends StatefulWidget {
  const DebtHome({super.key});

  @override
  State<DebtHome> createState() => _DebtHomeState();
}

class _DebtHomeState extends State<DebtHome> {
  List<Map<String, dynamic>> debts = [];

  @override
  void initState() {
    super.initState();
    loadDebts();
  }

  Future<void> loadDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('debts');
    if (data != null) {
      setState(() {
        debts = List<Map<String, dynamic>>.from(
          jsonDecode(data).map((e) => Map<String, dynamic>.from(e)),
        );
      });
    }
  }

  Future<void> saveDebts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('debts', jsonEncode(debts));
  }

  double total(String type) {
    return debts
        .where((d) => d['type'] == type)
        .fold(0.0, (sum, d) => sum + (d['amount'] as num).toDouble());
  }

  Future<void> addDebt() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String type = 'Мне должны';
    String currency = 'KGS';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, refresh) {
            return AlertDialog(
              title: const Text('Новая запись'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя человека',
                        hintText: 'Например, Алексей',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Сумма',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Тип долга'),
                      items: ['Мне должны', 'Я должен']
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(v),
                              ))
                          .toList(),
                      onChanged: (v) => refresh(() => type = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'Валюта'),
                      items: ['KGS', 'USD', 'EUR', 'RUB']
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(v),
                              ))
                          .toList(),
                      onChanged: (v) => refresh(() => currency = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(
                      amountController.text.replaceAll(',', '.'),
                    );

                    if (name.isEmpty || amount == null || amount <= 0) {
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'name': name,
                      'amount': amount,
                      'type': type,
                      'currency': currency,
                    });
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    amountController.dispose();

    if (result != null) {
      setState(() => debts.add(result));
      await saveDebts();
    }
  }

  Future<void> deleteDebt(int index) async {
    setState(() => debts.removeAt(index));
    await saveDebts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ДОЛГ КОНТРОЛ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: summaryCard(
                    'Мне должны',
                    total('Мне должны'),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: summaryCard(
                    'Я должен',
                    total('Я должен'),
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Мои записи',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: debts.isEmpty
                ? const Center(
                    child: Text(
                      'Пока записей нет.\nНажми +, чтобы добавить долг.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: debts.length,
                    itemBuilder: (context, index) {
                      final debt = debts[index];
                      final isOwed = debt['type'] == 'Мне должны';

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              isOwed ? Icons.call_received : Icons.call_made,
                            ),
                          ),
                          title: Text(
                            debt['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(debt['type']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${debt['amount']} ${debt['currency']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => deleteDebt(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addDebt,
        icon: const Icon(Icons.add),
        label: const Text('Добавить долг'),
      ),
    );
  }

  Widget summaryCard(String title, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
