import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import 'model.dart';

class ChatPage extends StatefulWidget {
  final String character;

  const ChatPage({
    super.key,
    required this.character,
  });

  @override
  State<StatefulWidget> createState() {
    return _ChatPageState();
  }
}

class _ChatPageState extends State<ChatPage> {
  late final OpenAI _openAI;
  late bool _isLoading;
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  final _voiceMode = false;

  final TextEditingController _textController = TextEditingController();
  late List<ChatMessage> _messages;

  @override
  void initState() {
    _messages = [];
    _isLoading = false;
    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    // Initialize ChatGPT SDK
    _openAI = OpenAI.instance.build(
      token: dotenv.env['OPENAI_API_KEY'],
      baseOption: HttpSetup(
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // This tells ChatGPT what his role is
    _handleInitialMessage(
      'You are a ${widget.character.toLowerCase()}. Please send a super short intro message. Your name is Echo.',
    );
    super.initState();
  }

  void _startListening() async {
      if (!_isListening) {
        bool available = await _speech.initialize(
          onStatus: (val) {
            if (val == 'done') {
              _stopListening();
            }
          },
          onError: (val) {
            _stopListening();
          },
        );
        if (available) {
          _speech.listen(
            onResult: (val) {
              setState(() {
                _textController.text = val.recognizedWords;
                if (val.recognizedWords.endsWith('Finished')) {
                  _handleSubmit(_textController.text.replaceAll('Finished', '').trim());
                  _stopListening();
                }
              });
            },
            listenFor: const Duration(minutes: 1), // Set a longer timeout duration
            pauseFor: const Duration(seconds: 5), // Set a pause duration
          );
          setState(() => _isListening = true);
        }
      } else {
        _stopListening();
      }
    }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
    _startListening();
  }

  Future<void> _handleInitialMessage(String character) async {
    setState(() {
          _isLoading = true;
        });

    final request = ChatCompleteText(
      messages: [
        Map.of({"role": "assistant", "content": character})
      ],
      maxToken: 200,
      model: ChatModel.gpt_4,
    );

    final response = await _openAI.onChatCompletion(request: request);

    ChatMessage message = ChatMessage(
      text: (response?.choices.first.message?.content ?? '').trim().replaceAll('"', ''),
      isSentByMe: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, message);
      _isLoading = false;
    });
  }

  Future<void> _handleSubmit(String text) async {
      setState(() {
        _isLoading = true;
      });
      _textController.clear();

      // Add the user sent message to the thread
      ChatMessage prompt = ChatMessage(
        text: text,
        isSentByMe: true,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.insert(0, prompt);
      });

      // Handle ChatGPT request and response
      final request = ChatCompleteText(
        messages: [
          Map.of({"role": "user", "content": text})
        ],
        maxToken: 200,
        model: ChatModel.gpt_4,
      );
      final response = await _openAI.onChatCompletion(request: request);

      // Add the user received message to the thread
      ChatMessage message = ChatMessage(
        text: (response?.choices.first.message?.content ?? '').trim().replaceAll('"', ''),
        isSentByMe: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.insert(0, message);
        _isLoading = false;
      });

      if (_voiceMode) {
        _speak(message.text);
      }
  }

  Widget _buildChatList() {
    return Flexible(
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        reverse: true,
        itemCount: _messages.length,
        itemBuilder: (_, int index) {
          ChatMessage message = _messages[index];
          return _buildChatBubble(message);
        },
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isSentByMe = message.isSentByMe;
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              margin: isSentByMe
                  ? const EdgeInsets.only(left: 100)
                  : const EdgeInsets.only(right: 100),
              decoration: BoxDecoration(
                color: isSentByMe ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12.0),
                  topRight: const Radius.circular(12.0),
                  bottomLeft: isSentByMe
                      ? const Radius.circular(12.0)
                      : const Radius.circular(0.0),
                  bottomRight: isSentByMe
                      ? const Radius.circular(0.0)
                      : const Radius.circular(12.0),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSentByMe
                        ? 'You'
                        : '@Echo_${widget.character.toString().replaceAll(' ', '')}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSentByMe ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isSentByMe ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${dateFormat.format(message.timestamp)} at ${timeFormat.format(message.timestamp)}',
                    style: TextStyle(
                      color: isSentByMe ? Colors.white : Colors.black87,
                      fontSize: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatComposer() {
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                keyboardType: TextInputType.multiline,
                maxLines: 5,
                minLines: 5,
                decoration: InputDecoration.collapsed(
                  hintText: 'Type a message',
                  enabled: !_isLoading,
                ),
                onSubmitted: _isLoading ? null : _handleSubmit,
              ),
            ),
            IconButton(
              icon: Icon(_voiceMode ? (_isListening ? Icons.pause : Icons.mic) : Icons.mic_off),
              onPressed: _voiceMode ? _startListening : null,
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _isLoading
                  ? null
                  : () => _handleSubmit(
                        _textController.text,
                      ),
            ),
          ],
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
          ),
        ),
        title: const Text(
          'Echo Chat',
          style: TextStyle(
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Stack(
          children: [
            Column(
              children: [
                _buildChatList(),
                const Divider(height: 1.0),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                  ),
                  child: _buildChatComposer(),
                ),
              ],
            ),
            if (_isLoading)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  child: const CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}