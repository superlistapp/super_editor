import 'package:flutter/material.dart';
import 'package:slack/domain/message.dart';
import 'package:slack/domain/user.dart';
import 'package:slack/fake_data/fake_messages.dart';
import 'package:slack/fake_data/fake_users.dart';
import 'package:slack/chat_thread.dart';
import 'package:slack/mobile_message_editor.dart';
import 'package:slack/styles.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  runApp(
    const MaterialApp(
      home: SlackChatPage(),
    ),
  );
}

/// A Slack-like UI containing a list of messages and a message editor.
///
/// Messages are loaded from markdown and can contain rich content, like list items,
/// headers, images, user mentions, etc.
class SlackChatPage extends StatefulWidget {
  const SlackChatPage({super.key});

  @override
  State<SlackChatPage> createState() => _SlackChatPageState();
}

class _SlackChatPageState extends State<SlackChatPage> {
  final ScrollController _messageListScrollController = ScrollController();
  final GlobalKey _scaffoldKey = GlobalKey();

  final User _user = fakeUsers[1];
  final List<Message> _messages = [...fakeMessages];

  @override
  void dispose() {
    _messageListScrollController.dispose();
    super.dispose();
  }

  void _onSendMessage(Document document) {
    if (document.length == 1 &&
        document.first is ParagraphNode &&
        (document.first as ParagraphNode).text.toPlainText().trim().isEmpty) {
      // The message editor is empty. Fizzle.
      return;
    }

    setState(() {
      _messages.add(Message(
        userId: '1',
        sentAt: DateTime.now(),
        content: document,
      ));
    });

    // Scroll the message list to display the newly added message.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) {
        return;
      }

      _messageListScrollController.animateTo(
        _messageListScrollController.position.minScrollExtent,
        // ^ minScrollExtent because the list is reversed.
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        // ^ Don't add padding at the bottom of the screen because
        // we handle it ourselves.
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // TODO: implement desktop screen.
    return _SlackChatMobile(
      scaffoldKey: _scaffoldKey,
      onSendMessage: _onSendMessage,
      user: _user,
      messages: _messages,
      scrollController: _messageListScrollController,
    );
  }
}

class _SlackChatMobile extends StatefulWidget {
  const _SlackChatMobile({
    required this.scaffoldKey,
    required this.onSendMessage,
    required this.user,
    required this.messages,
    required this.scrollController,
  });

  final GlobalKey scaffoldKey;
  final OnSendMessage onSendMessage;
  final User user;
  final List<Message> messages;
  final ScrollController scrollController;

  @override
  State<_SlackChatMobile> createState() => _SlackChatMobileState();
}

class _SlackChatMobileState extends State<_SlackChatMobile> {
  final _messagePageController = MessagePageController();

  @override
  Widget build(BuildContext context) {
    return MessagePageScaffold(
      controller: _messagePageController,
      bottomSheetMinimumTopGap: 150,
      bottomSheetMinimumHeight: 120,
      contentBuilder: (contentContext, bottomSpacing) {
        return MediaQuery.removePadding(
          context: contentContext,
          removeBottom: true,
          // ^ Remove bottom padding because if we don't, when the keyboard
          //   opens to edit the bottom sheet, this content behind the bottom
          //   sheet adds some phantom space at the bottom, slightly pushing
          //   it up for no reason.
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: bottomSpacing,
                child: _buildChatThread(),
              ),
            ],
          ),
        );
      },
      bottomSheetBuilder: (messageContext) {
        return _buildBottomSheet();
      },
    );
  }

  Widget _buildChatThread() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTopSection(),
        Divider(color: dividerColor),
        Expanded(
          child: ChatThread(
            messages: widget.messages,
            backgroundColor: backgroundColor,
            scrollController: widget.scrollController,
          ),
        ),
      ],
    );
  }

  /// Builds the top section of the chat, containing the back button, the user avatar with the
  /// user's name, and the headphones icon.
  Widget _buildTopSection() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () {},
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                height: 50,
                padding: EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  color: Color(0xFF21252A),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.user.avatarUrl,
                            fit: BoxFit.cover,
                            height: 50,
                          ),
                        ),
                        Positioned(
                          bottom: -1,
                          right: -4,
                          child: Container(
                            height: 18,
                            width: 18,
                            padding: EdgeInsets.all(3.0),
                            decoration: BoxDecoration(
                              color: Color(0xFF21252A),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFF3CAA7B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                    SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          widget.user.displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '3 tabs',
                              style: TextStyle(color: Colors.white),
                            ),
                            Transform.rotate(
                              angle: 270 * 3.14 / 180,
                              child: Icon(
                                Icons.chevron_left,
                                size: 19,
                                color: Colors.white,
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.headphones_outlined),
            color: Colors.white,
            onPressed: () {},
          )
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    return MobileMessageEditor(
      hintText: 'Message ${widget.user.displayName}',
      messagePageController: _messagePageController,
      onSendMessage: widget.onSendMessage,
    );
  }
}
