import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notulenize/style/color.dart';
import 'package:notulenize/summary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewPage {
  // Function to save summary to SharedPreferences
  static Future<void> _saveSummary(String summary) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> summaries = prefs.getStringList('meeting_summaries') ?? [];
    summaries.add(summary);
    await prefs.setStringList('meeting_summaries', summaries);
  }

  // Function to create a summary
  static Future<void> _createSummary(
    BuildContext context,
    String transcript,
    String recordingPath,
    String title,
    VoidCallback resetStateCallback,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(
                'Creating summary.....',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );

    String promptContext =
        "Please provide a concise summary of the following meeting transcription. The summary should capture the key points in each respective language (e.g, if the summary is in Indonesian language, generate in indonesian), highlighting the most significant themes discussed. Additionally, extract and list the 5 most important keywords or phrases from the text, based on their relevance and impact on the discussion. the summary: ";
    String prompt = promptContext + transcript;

    try {
      // Generate the summary using OpenAI API
      final summaryResponse = await OpenAI.instance.completion.create(
        model: 'gpt-3.5-turbo-instruct',
        prompt: prompt,
        maxTokens: 300,
        temperature: 0.2,
      );

      // Save the generated summary to SharedPreferences
      await _saveSummary(summaryResponse.choices.first.text);

      // Get the current date and time
      String formattedDate =
          DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());

      // Show a snackbar to inform the user that the summary is saved
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary saved!')),
      );

      // After the summary is created, dismiss the dialog and navigate to the SummaryPage
      Navigator.pop(context); // Dismiss the loading dialog

      // Navigate to the SummaryPage with the title, summary, transcript, and the formatted date
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SummaryPage(
            title: title,
            summary:
                summaryResponse.choices.first.text, // Corrected summary text
            transcript: transcript,
            formattedDate: formattedDate, // Pass the formatted date
            resetState: resetStateCallback,
          ),
        ),
      );
    } catch (e) {
      // Dismiss the loading dialog if an error occurs
      Navigator.pop(context);

      // Handle any error while creating the summary
      print("Error creating summary: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create summary')),
      );
    }
  }

  // Function to delete the transcript from SharedPreferences and the audio file from the device
  static Future<void> _deleteTranscriptAndAudio(
      BuildContext context,
      String transcript,
      String audioFilePath,
      VoidCallback resetStateCallback) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Delete the transcript from SharedPreferences
    List<String> summaries = prefs.getStringList('meeting_summaries') ?? [];
    summaries.removeWhere((summary) =>
        summary.contains(transcript)); // Find and remove the transcript
    await prefs.setStringList('meeting_summaries', summaries);

    // Show a snackbar to inform the user that the file is deleted
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript and audio file deleted!')),
    );

    // Call the resetState() method from the parent widget
    resetStateCallback(); // Reset the state of AudioToTextPage

    Navigator.pop(context); // Close the review page
  }

  // Function to show the ReviewPage as a bottom sheet
  static Widget showReviewBottomSheet(BuildContext context, String transcript,
      String title, String audioFilePath, VoidCallback resetStateCallback) {
    print("aremania:" + transcript);

    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm'),
              content: const Text('Are you sure you want to close this?'),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(false), // Do not pop
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () {
                    resetStateCallback(); // Call the resetState() function
                    Navigator.of(context).pop(true); // Pop
                  },
                  child: const Text('Yes'),
                ),
              ],
            ),
          );

          return shouldPop ?? false; // Return true to pop, false to not pop
        },
        child: Container(
          color: Colors.white,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                pinned: true,
                expandedHeight: 100.0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.zero,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset("assets/images/logo/logo.png"),
                    ],
                  ),
                  background: Container(
                    color: Colors.white,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primary400),
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      const Text(
                        "Raw Transcript:",
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        transcript,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _createSummary(context, transcript,
                                audioFilePath, title, resetStateCallback),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primary400),
                            child: const Text(
                              'Make Summary',
                              style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _deleteTranscriptAndAudio(context,
                                transcript, audioFilePath, resetStateCallback),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              side: BorderSide(color: primary400),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: primary400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
