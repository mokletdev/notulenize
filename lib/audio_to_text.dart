import 'package:dart_openai/dart_openai.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:notulenize/style/color.dart';
import 'package:notulenize/summary_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'dart:io';
import 'review_page.dart';

class AudioToTextPage extends StatefulWidget {
  @override
  _AudioToTextPageState createState() => _AudioToTextPageState();
}

class _AudioToTextPageState extends State<AudioToTextPage> {
  final _record = AudioRecorder();
  bool _isRecording = false;
  bool _hasRecorded = false;
  Timer? _timer;
  int _elapsedSeconds = 0;
  final TextEditingController _titleController = TextEditingController();
  String localRecordingPath = '';

  @override
  void initState() {
    super.initState();
    resetState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    resetState(); // Reset state every time the page is opened
  }

  Future<void> _initialize() async {
    await Permission.microphone.request();
  }

  void resetState() {
    if (_isRecording) {
      _record.stop();
    }
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _elapsedSeconds = 0;
      _titleController.clear();
      _hasRecorded = false;
    });
  }

  void _startRecording() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must set the title first!')),
      );
      return;
    }

    setState(() {
      _isRecording = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
    if (_hasRecorded == false) {
      setState(() {
        _hasRecorded = true;
      });
      final directory = await getExternalStorageDirectory();

      await _record.start(
        const RecordConfig(),
        path:
            '${directory?.path}/${_titleController.text}_${DateTime.now()}.wav',
      );
    } else {
      _record.resume();
    }
  }

  void _pauseRecording() async {
    if (_isRecording) {
      await _record.pause();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _handleFileUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      String? filePath = result.files.single.path;
      if (filePath != null) {
        // Get the file size
        final file = File(filePath);
        final fileSize = await file.length(); // Size in bytes

        // Check if the file size exceeds 10 MB (10 * 1024 * 1024 bytes)
        const maxSizeInBytes = 10 * 1024 * 1024; // 10 MB
        if (fileSize > maxSizeInBytes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size must not exceed 10 MB!')),
          );
          return; // Exit if the file size exceeds the limit
        }

        // Get the transcription from the selected file
        await _handleTranscriptionAndSummary(recordingPath: filePath);
      }
    }
  }

  Future<String?> makeTranscription(
      BuildContext context, String filePath) async {
    try {
      final audioFile = File(filePath);
      if (!await audioFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio file not found!')),
          );
        return null;
      }

      const snackBar = SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 10),
            Text("Transcribing..."),
          ],
        ),
        duration: Duration(
            days: 1),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);

      // Check if transcription already exists
      final transcriptionFilePath = '$filePath.transcription.txt';
      final transcriptionFile = File(transcriptionFilePath);

      // Set the timeout duration (e.g., 60 seconds)
      const timeoutDuration = Duration(seconds: 300);

      // Try to get the transcription with a timeout
      final transcript = await OpenAI.instance.audio
          .createTranscription(
        file: audioFile,
        model: 'whisper-1',
        responseFormat: OpenAIAudioResponseFormat.text,
      )
          .timeout(timeoutDuration, onTimeout: () {
        throw TimeoutException('Transcription request timed out');
      });

      // Save transcription to a file for future use
      await transcriptionFile.writeAsString(transcript.toString());

      // Hide the loading snackbar by calling ScaffoldMessenger.clearSnackBars
      ScaffoldMessenger.of(context).clearSnackBars();

      return transcript.text;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error $e')),
          );

      // Hide the loading snackbar in case of error
      ScaffoldMessenger.of(context).clearSnackBars();

      return null;
    }
  }

  Future<void> _handleTranscriptionAndSummary(
      {String recordingPath = ''}) async {
    if (recordingPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording path is empty')),
          );
      recordingPath = (await _record.stop())!;
    }

    String? transcript = await makeTranscription(context, recordingPath);

    if (transcript != null) {
      // Step 2: Generate summary from the transcription

      // Step 3: Navigate to the ReviewPage with the summary
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return ReviewPage.showReviewBottomSheet(context, transcript,
              _titleController.text, recordingPath, resetState);
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No recording path found')),
          );
    }
  }

  Future<void> deleteRecording() async {
    // Show confirmation dialog before resetting state
    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text(
              'Are you sure you want to delete the current recording?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // No, don't delete
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Yes, delete
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        // Get the recording path
        String? path = await _record.stop(); // Ensure the stop method gives the recording path
        if (path != null) {
          final audioFile = File(path);

          // Check if the recording file exists and delete it
          if (await audioFile.exists()) {
            await audioFile.delete();
          }

          // Reset the state after deletion
          resetState();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording has been deleted.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting recording $e')),
          );
      }
    }
  }

  @override
  void dispose() {
    _pauseRecording();
    _timer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  String _formatElapsedTime(int seconds) {
    final hours = (seconds ~/ 3600);
    final minutes = (seconds ~/ 60) % 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      resizeToAvoidBottomInset: false,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Image.asset('assets/images/logo/logo.png'),
                const SizedBox(height: 50),
                const Text(
                  "Meeting Title: ",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    color: primary400,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '....',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                    ),
                  ),
                  enabled: !_hasRecorded,
                ),
                const SizedBox(height: 8),
                Image.asset('assets/images/underline.png'),
              ],
            ),
            SizedBox(
              height: 400,
              child: Column(
                children: [
                  Text(
                    _formatElapsedTime(_elapsedSeconds),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isRecording
                        ? 'Tap to pause recording'
                        : 'Tap to start recording',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _isRecording ? _pauseRecording : _startRecording,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary400,
                      ),
                      child: Center(
                        child: _isRecording
                            ? const Text(
                                'Pause',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Image.asset('assets/images/microphone-icon.png'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (!_isRecording && _hasRecorded)
                    ElevatedButton(
                      onPressed: _handleTranscriptionAndSummary,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: primary400),
                      child: const Text(
                        'Stop & See transcription',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Button for Deleting Recording
                  if (!_isRecording && _hasRecorded)
                    ElevatedButton(
                      onPressed: deleteRecording,
                      style: ElevatedButton.styleFrom(
                          elevation: 0, side: BorderSide(color: primary400)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Icon(
                            Icons.delete,
                            color: primary400,
                          ),
                          Text(
                            'Delete Recording',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              color: primary400,
                            ),
                          ),
                          const SizedBox(),
                        ],
                      ),
                    ),
                  if (!_isRecording && !_hasRecorded)
                    ElevatedButton(
                      onPressed: () {
                        if (_titleController.text.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text("You must set the title first"),
                          ));
                          return;
                        }
                        _handleFileUpload();
                      },
                      style: ElevatedButton.styleFrom(
                          side: BorderSide(color: primary400), elevation: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.file_upload_outlined,
                            color: primary400,
                          ),
                          Text(
                            'Upload Meeting Audio',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              color: primary400,
                            ),
                          ),
                          const SizedBox()
                        ],
                      ),
                    )
                  else
                    const SizedBox(),
                  const SizedBox(
                    height: 6,
                  ),
                  const SizedBox(
                    height: 20,
                  )
                ],
              ),
            ),
            if (!_isRecording && !_hasRecorded)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SummaryPage(
                        resetState: resetState,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: primary400),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.file_open,
                      color: Colors.white,
                    ),
                    Text(
                      'See summary history',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox()
                  ],
                ),
              )
            else
              const SizedBox(),
            const SizedBox(
              height: 6,
            ),
          ],
        ),
      ),
    );
  }
}
