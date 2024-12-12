import 'package:flutter/material.dart';
import 'package:notulenize/audio_to_text.dart';
import 'package:notulenize/style/color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'detail_page.dart'; // Import the DetailPage

class SummaryPage extends StatefulWidget {
  final String? title; // Make title optional
  final String? summary; // Make summary optional
  final String? transcript; // Make transcript optional
  final String? formattedDate;
  final void Function() resetState; // Add resetState callback

  const SummaryPage({
    Key? key,
    this.title, // Use nullable type
    this.summary, // Use nullable type
    this.transcript, // Use nullable type
    this.formattedDate,
    required this.resetState, // Required resetState callback
  }) : super(key: key);

  @override
  _SummaryPageState createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late Future<void> _loadDataFuture;

  @override
  void initState() {
    super.initState();
    _loadDataFuture = _loadData(); // Initialize the future for loading data
  }

  Future<void> _loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Load the lists from SharedPreferences
    final meetingTitles = prefs.getStringList('meeting_titles') ?? [];
    final meetingDates = prefs.getStringList('meeting_dates') ??
        []; // New list to store the dates
    final transcriptions = prefs.getStringList('transcriptions') ?? [];
    final summaries = prefs.getStringList('summaries') ?? [];

    // Ensure all lists are of the same length
    if (meetingTitles.length == transcriptions.length &&
        meetingTitles.length == summaries.length &&
        meetingTitles.length == meetingDates.length) {
      setState(() {
        _meetingTitles = meetingTitles;
        _meetingDates = meetingDates;
        _transcriptions = transcriptions;
        _summaries = summaries;
      });
    } else {
      // Handle the case where the lists are not in sync
      setState(() {
        _meetingTitles = [];
        _meetingDates = [];
        _transcriptions = [];
        _summaries = [];
      });
      print('Error: Lists are not in sync.'); // Log the error for debugging
    }

    // Add the new summary to the list if parameters are provided
    if (widget.title != null &&
        widget.summary != null &&
        widget.transcript != null &&
        widget.formattedDate != null) {
      await _addNewSummary();
    }
  }

  // Lists to hold meeting titles, transcriptions, summaries, and formatted dates
  List<String> _meetingTitles = [];
  List<String> _meetingDates = []; // New list for dates
  List<String> _transcriptions = [];
  List<String> _summaries = [];

  // Add the new summary to the list and SharedPreferences
  Future<void> _addNewSummary() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Add the new summary, title, transcript, and formatted date
    _meetingTitles.add(widget.title!); // Use ! to assert non-null
    _meetingDates.add(widget.formattedDate!); // Use the formatted date
    _transcriptions.add(widget.transcript!); // Use ! to assert non-null
    _summaries.add(widget.summary!); // Use ! to assert non-null

    // Save the updated lists to SharedPreferences
    await prefs.setStringList('meeting_titles', _meetingTitles);
    await prefs.setStringList('meeting_dates', _meetingDates); // Save the dates
    await prefs.setStringList('transcriptions', _transcriptions);
    await prefs.setStringList('summaries', _summaries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset('assets/images/logo/logo.png'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Custom back button
          onPressed: () {
            // Call the resetState before navigating to AudioToTextPage
            widget.resetState.call(); // Reset state in AudioToTextPage

            // Navigate to AudioToTextPage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      AudioToTextPage()), // Replace current page with AudioToTextPage
            );
          },
        ),
      ),
      body: FutureBuilder<void>(
        future: _loadDataFuture, // The Future that will load the data
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator()); // Show loading indicator
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}')); // Handle errors
          } else {
            return _meetingTitles.isEmpty
                ? const Center(
                    child: Text('No summaries available.')) // No data available
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Image.asset(
                                "assets/images/summary-history.png"),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _meetingTitles = [];
                                _meetingDates = [];
                                _transcriptions = [];
                                _summaries = [];
                                _loadDataFuture = _loadData();
                              });
                            },
                            icon: Icon(
                              Icons.refresh,
                              color: primary400,
                            ),
                          )
                        ],
                      ),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _meetingTitles.length,
                          itemBuilder: (context, index) {
                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: primary400,
                                  ),
                                  borderRadius: BorderRadius.circular(15)),
                              child: ListTile(
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _meetingDates[index], // Display the date
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: primary400,
                                      ),
                                    ),
                                    Text(
                                      _meetingTitles[index],
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: primary400,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _transcriptions[index].length > 100
                                          ? _transcriptions[index]
                                                  .substring(0, 100) +
                                              '...' // Show a glimpse of the transcript
                                          : _transcriptions[index],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  // Navigate to DetailPage and pass the data
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailPage(
                                        title: _meetingTitles[index],
                                        transcription: _transcriptions[index],
                                        summary: _summaries[index],
                                        formattedDate: _meetingDates[index],
                                      ),
                                    ),
                                  );

                                  // If the result is true, reload the data
                                  if (result == true) {
                                    setState(() {
                                      _loadDataFuture =
                                          _loadData(); // Reload the data
                                    });
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
          }
        },
      ),
    );
  }
}
