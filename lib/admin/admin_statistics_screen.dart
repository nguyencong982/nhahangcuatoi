import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  static const String _cloudRunBaseUrl = 'https://revenue-service-1096129874429.us-central1.run.app';
  static const String _apiEndpoint = '/api/v1/admin/revenue-report';
  static const String _cloudRunUrl = '$_cloudRunBaseUrl$_apiEndpoint';

  double _totalRevenue = 0.0;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _transactionDetails = [];

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int? _selectedDay;

  List<BarChartGroupData> _dailyRevenueData = [];

  @override
  void initState() {
    super.initState();
    _fetchRevenueAndTransactions();
  }

  Future<void> _fetchRevenueAndTransactions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Lỗi: Người dùng chưa đăng nhập.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _totalRevenue = 0.0;
      _transactionDetails = [];
      _dailyRevenueData = [];
    });

    try {
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        throw Exception('Không thể lấy ID Token hợp lệ.');
      }

      final response = await http.post(
        Uri.parse(_cloudRunUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'year': _selectedYear,
          'month': _selectedMonth,
          'day': _selectedDay,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final revenue = (data['totalRevenue'] as num).toDouble();
        final dailyRevenueMapRaw = (data['dailyRevenueMap'] as Map<String, dynamic>);

        final Map<int, double> dailyRevenueMap = dailyRevenueMapRaw.map(
              (key, value) => MapEntry(int.parse(key), (value as num).toDouble()),
        );

        final fetchedTransactions = (data['transactionDetails'] as List)
            .map((tx) => {
          'id': tx['id'],
          'itemsSummary': tx['itemsSummary'],
          'totalAmount': (tx['totalAmount'] as num).toDouble(),
          'timestamp': DateTime.parse(tx['timestamp']),
        })
            .toList();

        List<BarChartGroupData> barGroups = [];
        int daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
        for (int i = 1; i <= daysInMonth; i++) {
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: dailyRevenueMap[i] ?? 0,
                  color: Colors.blue,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          );
        }

        setState(() {
          _totalRevenue = revenue;
          _transactionDetails = fetchedTransactions;
          _dailyRevenueData = barGroups;
          _isLoading = false;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error'] ?? 'Lỗi không rõ khi xác thực.';
        throw Exception('Lỗi truy cập (${response.statusCode}): $errorMsg. Vui lòng kiểm tra vai trò Admin.');
      } else {
        throw Exception('Lỗi HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('Exception:')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Lỗi không xác định: $e';
        _isLoading = false;
      });
      print('Lỗi tải thống kê: $e');
    }
  }

  List<int> get _availableYears {
    return List<int>.generate(5, (index) => DateTime.now().year - index);
  }

  List<int> get _availableDaysInMonth {
    int days = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    return List<int>.generate(days, (index) => index + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thống kê Doanh thu', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: InputDecoration(labelText: 'Năm', labelStyle: GoogleFonts.poppins()),
                    items: _availableYears
                        .map((year) =>
                        DropdownMenuItem(value: year, child: Text('$year', style: GoogleFonts.poppins())))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedYear = value;
                          _selectedDay = null;
                        });
                        _fetchRevenueAndTransactions();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: InputDecoration(labelText: 'Tháng', labelStyle: GoogleFonts.poppins()),
                    items: List.generate(12, (index) => index + 1)
                        .map((month) => DropdownMenuItem(
                        value: month, child: Text('Tháng $month', style: GoogleFonts.poppins())))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedMonth = value;
                          _selectedDay = null;
                        });
                        _fetchRevenueAndTransactions();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _selectedDay,
                    decoration: InputDecoration(labelText: 'Ngày', labelStyle: GoogleFonts.poppins()),
                    items: [
                      DropdownMenuItem<int?>(
                          value: null, child: Text('Tất cả ngày', style: GoogleFonts.poppins())),
                      ..._availableDaysInMonth
                          .map((day) =>
                          DropdownMenuItem(value: day, child: Text('$day', style: GoogleFonts.poppins())))
                          .toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDay = value;
                      });
                      _fetchRevenueAndTransactions();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Tổng doanh thu:',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800]),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : _errorMessage != null
                      ? Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  )
                      : Text(
                    '${NumberFormat('#,##0', 'vi_VN').format(_totalRevenue)} VNĐ',
                    style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Doanh thu theo ngày',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)))
                : SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: _dailyRevenueData,
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xff37434d), width: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(value.toInt().toString(),
                                style: GoogleFonts.poppins(fontSize: 10)),
                          );
                        },
                        reservedSize: 20,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt() ~/ 1000}K',
                              style: GoogleFonts.poppins(fontSize: 10));
                        },
                        reservedSize: 30,
                      ),
                    ),
                    topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Color(0xff37434d),
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _dailyRevenueData.isNotEmpty
                      ? _dailyRevenueData
                      .map((group) => group.barRods.first.toY)
                      .reduce((a, b) => a > b ? a : b) *
                      1.2
                      : 100,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chi tiết giao dịch:',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)))
                : _transactionDetails.isEmpty
                ? Center(
              child: Text(
                'Không có giao dịch nào trong khoảng thời gian này.',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            )
                : Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _transactionDetails.length,
                itemBuilder: (context, index) {
                  final transaction = _transactionDetails[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sản phẩm:\n${transaction['itemsSummary']}',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Tổng tiền: ${NumberFormat('#,##0', 'vi_VN').format(transaction['totalAmount'])} VNĐ',
                            style: GoogleFonts.poppins(
                                fontSize: 15, color: Colors.deepOrange),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(transaction['timestamp'])}',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.grey[700]),
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
      ),
    );
  }
}
