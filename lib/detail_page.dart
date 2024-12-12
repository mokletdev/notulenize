import 'package:flutter/material.dart';
import 'package:notulenize/style/color.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailPage extends StatefulWidget {
  final String title;
  final String transcription;
  final String summary;
  final String formattedDate; // Add formattedDate parameter

  const DetailPage({
    Key? key,
    required this.title,
    required this.transcription,
    required this.summary,
    required this.formattedDate, // Add formattedDate parameter
  }) : super(key: key);

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  String _selectedView = 'Transcript'; // Default view is Transcript

  // Function to delete the entry from SharedPreferences
  Future<void> _deleteEntry(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get the current list of titles and transcriptions
    List<String> meetingTitles = prefs.getStringList('meeting_titles') ?? [];
    List<String> transcriptions = prefs.getStringList('transcriptions') ?? [];
    List<String> summaries = prefs.getStringList('summaries') ?? [];
    List<String> meetingDates = prefs.getStringList('meeting_dates') ?? [];

    // Remove the entry from the list
    meetingTitles.remove(widget.title);
    transcriptions.remove(widget.transcription);
    summaries.remove(widget.summary);
    meetingDates.remove(widget.formattedDate); // Remove the date

    // Save the updated lists back to SharedPreferences
    await prefs.setStringList('meeting_titles', meetingTitles);
    await prefs.setStringList('transcriptions', transcriptions);
    await prefs.setStringList('summaries', summaries);
    await prefs.setStringList('meeting_dates', meetingDates); // Save the dates

    // Show a snackbar to inform the user that the entry was deleted
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry deleted')),
    );

    // Navigate back to the previous page (SummaryPage)
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset("assets/images/logo/logo.png"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // Confirm before deleting the entry
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Delete Entry'),
                    content: const Text(
                        'Are you sure you want to delete this entry?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          // Cancel deletion
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          // Delete the entry and return to SummaryPage
                          _deleteEntry(context);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        // Wrap the body in SingleChildScrollView to avoid overflow
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.formattedDate, // Display the date
                style: TextStyle(
                  fontSize: 16,
                  color: primary400,
                ),
              ),
              Text(
                widget.title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    color: primary400),
              ),
              const SizedBox(height: 10),
              // Display the formatted date

              const SizedBox(height: 20),
              // Dropdown to toggle between Transcript and Summary
              DropdownButton<String>(
                value: _selectedView,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedView = newValue!;
                  });
                },
                items: const [
                  DropdownMenuItem(
                    value: 'Transcript',
                    child: Text(
                      'Transcript',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Summary',
                    child: Text(
                      'Summary',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Show either Transcript or Summary based on selection
              _selectedView == 'Transcript'
                  ? Text(
                      widget.transcription,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      widget.summary,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
