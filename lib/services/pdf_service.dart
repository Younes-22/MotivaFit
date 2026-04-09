import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
// We import the pdf widgets as 'pw' so Flutter doesn't get confused between a regular Flutter 'Column' and a PDF 'Column'.
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart';

// This service acts as the app's personal secretary. It gathers up all the user's accomplishments from the past week, formats them into a clean document, and hands it over to the phone's native sharing menu.
class PdfService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generates the PDF. Unlike our normal UI which uses Streams for live updates, this method uses `.get()` to take a single, static snapshot of the database exactly as it looks right this second.
  Future<void> generateAndDownloadReport() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Data gathering
    
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    
    // Establish the time window (Midnight 7 days ago to right now)
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final startDate = Timestamp.fromDate(sevenDaysAgo);

    // Fetch the last week of Tasks to calculate consistency
    final tasksQuery = await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('scheduledDate', isGreaterThanOrEqualTo: startDate)
        .get();

    int totalTasks = tasksQuery.docs.length;
    int completedTasks = tasksQuery.docs.where((d) => d['isCompleted'] == true).length;

    // Fetch the last week of Nutrition to build the table
    final nutritionQuery = await _db
        .collection('users')
        .doc(uid)
        .collection('nutrition')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .get();

    // Document building
    
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("MotivaFit Weekly Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('yyyy-MM-dd').format(now)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // User stats box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat("Username", userData['username'] ?? 'User'),
                    _buildStat("Level", "${userData['currentLevel'] ?? 1}"),
                    _buildStat("Current Coins", "${userData['currentCoins'] ?? 0}"),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Task summary
              pw.Text("Task Consistency", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Paragraph(text: "In the last 7 days, you have completed $completedTasks out of $totalTasks scheduled tasks."),
              pw.SizedBox(height: 10),
              
              // A visual bar showing their completion percentage
              pw.LinearProgressIndicator(
                value: totalTasks == 0 ? 0 : completedTasks / totalTasks,
                minHeight: 10,
                backgroundColor: PdfColors.grey300,
                valueColor: PdfColors.green,
              ),

              pw.SizedBox(height: 30),

              // Nutrition table
              pw.Text("Nutrition Logs (Last 7 Days)", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headerHeight: 25,
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                },
                headers: ['Date', 'Calories', 'Protein', 'Carbs', 'Fat'],
                data: nutritionQuery.docs.map((doc) {
                  final data = doc.data();
                  final date = (data['date'] as Timestamp).toDate();
                  return [
                    DateFormat('MM-dd').format(date),
                    "${data['calories']}",
                    "${data['protein']}g",
                    "${data['carbs']}g",
                    "${data['fat']}g",
                  ];
                }).toList(),
              ),

              // Footer
              pw.Spacer(),
              pw.Footer(
                leading: pw.Text("Generated by MotivaFit"),
                trailing: pw.Text("Keep pushing!"),
              ),
            ],
          );
        },
      ),
    );

    // Export & share
    
    // Instead of forcing a silent download, this automatically pops open the iOS/Android share sheet so the user can email it, message it, or save it to their files.
    await Printing.sharePdf(
      bytes: await pdf.save(), 
      filename: 'motivafit_report_${DateFormat('yyyyMMdd').format(now)}.pdf'
    );
  }

  // A tiny helper to draw the individual stat blocks in the top container
  pw.Widget _buildStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
}