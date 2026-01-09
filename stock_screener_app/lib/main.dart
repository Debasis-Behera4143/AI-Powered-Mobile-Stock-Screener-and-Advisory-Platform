import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const StockApp());
}

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stock Screener',
      home: const StockScreen(),
    );
  }
}

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final TextEditingController _queryController = TextEditingController();
  List stocks = [];
  bool loading = false;

  // 🔴 CHANGE IP IF NEEDED
  final String apiUrl = "http://192.168.1.5:3000/stocks";

  Future<void> screenStocks() async {
    setState(() {
      loading = true;
      stocks = [];
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          stocks = jsonDecode(response.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📈 Stock Screener")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 English query input
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: "Enter screener query",
                hintText: "e.g. stocks with pe less than 30",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 Screen button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: screenStocks,
                child: const Text("Screen"),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 Result section
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : stocks.isEmpty
                      ? const Center(child: Text("No results"))
                      : ListView.builder(
                          itemCount: stocks.length,
                          itemBuilder: (context, index) {
                            final stock = stocks[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                title: Text(
                                  stock["ticker"],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "Company: ${stock["company_name"]}\n"
                                  "Sector: ${stock["sector"]}\n"
                                  "PE: ${stock["pe_ratio"]}\n"
                                  "ROE: ${stock["roe"]}\n"
                                  "Market Cap: ${stock["market_cap"]}",
                                ),
                              ),
                            );
                          },
                        ),
            )
          ],
        ),
      ),
    );
  }
}
