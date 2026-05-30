import 'package:flutter/material.dart'; 
import 'api_service.dart'; 
 
class ChatPage extends StatefulWidget { 
  @override 
  _ChatPageState createState() => _ChatPageState(); 
} 
 
class _ChatPageState extends State<ChatPage> { 
  final TextEditingController _controller = TextEditingController(); 
  final List<Map<String, dynamic>> _messages = []; 
  bool _isTyping = false; 
 
  void _sendMessage() async { 
    if (_controller.text.isEmpty) return; 
 
    String userMsg = _controller.text; 
    setState(() { 
      _messages.add({"text": userMsg, "isUser": true}); 
      _isTyping = true; 
    }); 
    _controller.clear(); 
 
    // Panggil API NLP dari python 
    String botRes = await ApiService().askChatbot(userMsg); 
 
    setState(() { 
      _messages.add({"text": botRes, "isUser": false}); 
      _isTyping = false; 
    }); 
  } 
 
  @override 
  Widget build(BuildContext context) { 
    return Scaffold( 
      appBar: AppBar( 
        title: const Text("Tanya Bank Sampah"), 
        backgroundColor: Colors.green[700], 
        foregroundColor: Colors.white, 
      ), 
      body: Column( 
        children: [ 
          Expanded( 
            child: ListView.builder( 
              padding: const EdgeInsets.all(15), 
              itemCount: _messages.length, 
              itemBuilder: (context, index) { 
                final msg = _messages[index]; 
                return Align( 
                  alignment: msg['isUser'] ? Alignment.centerRight : 
Alignment.centerLeft, 
                  child: Container( 
                    margin: const EdgeInsets.symmetric(vertical: 5), 
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 
10), 
                    decoration: BoxDecoration( 
                      color: msg['isUser'] ? Colors.green[100] : 
Colors.grey[200], 
                      borderRadius: BorderRadius.circular(15), 
                    ), 
                    child: Text(msg['text']), 
                  ), 
                ); 
              }, 
            ), 
          ), 
          if (_isTyping) const LinearProgressIndicator(color: Colors.green), 
          Padding( 
            padding: const EdgeInsets.all(8.0), 
            child: Row( 
              children: [ 
                Expanded( 
                  child: TextField( 
                    controller: _controller, 
                    decoration: InputDecoration( 
                      hintText: "Tanya sesuatu...", 
                      border: OutlineInputBorder(borderRadius: 
BorderRadius.circular(25)), 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20), 
                    ), 
                  ), 
                ), 
                const SizedBox(width: 8), 
                FloatingActionButton( 
                  onPressed: _sendMessage, 
                  mini: true, 
                  backgroundColor: Colors.green, 
                  child: const Icon(Icons.send, color: Colors.white), 
                ), 
              ], 
            ), 
          ), 
        ], 
      ), 
    ); 
  } 
} 