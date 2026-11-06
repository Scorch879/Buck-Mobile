import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/ai_chat_message.dart';
import '../../data/services/buck_ai_service.dart';

/// Opens the floating Buck AI Financial Advisor interactive chat sheet.
Future<void> showAiChatSheet(BuildContext context, {BuckAiService? aiService}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AiChatSheetContent(
      aiService: aiService ?? BuckAiService.instance,
    ),
  );
}

class _AiChatSheetContent extends StatefulWidget {
  final BuckAiService aiService;

  const _AiChatSheetContent({required this.aiService});

  @override
  State<_AiChatSheetContent> createState() => _AiChatSheetContentState();
}

class _AiChatSheetContentState extends State<_AiChatSheetContent> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _activeStreamSub;
  String? _activeAiMsgId;
  bool _isStreaming = false;

  static const _quickPrompts = [
    'How is my spending looking this month?',
    "What's my daily spending limit?",
    'Can I afford dining out tonight?',
    'Give me advice to reach my goals',
  ];

  List<AiChatMessage> get _messages => widget.aiService.chatHistory;

  @override
  void initState() {
    super.initState();
    // Sanitize any stale streaming state from a previously dismissed sheet.
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].isStreaming) {
        _messages[i] = _messages[i].copyWith(
          text: _messages[i].text.isEmpty
              ? 'Response interrupted.'
              : _messages[i].text,
          isStreaming: false,
        );
      }
    }
    if (_messages.isEmpty) {
      _messages.add(
        AiChatMessage(
          id: 'initial',
          text:
              'Hello! I am your **Buck AI Financial Advisor**. Ask me anything about your spending, budget, or financial goals.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _activeStreamSub?.cancel();
    _activeStreamSub = null;
    if (_activeAiMsgId != null) {
      final idx = _messages.indexWhere((m) => m.id == _activeAiMsgId);
      if (idx != -1 && _messages[idx].isStreaming) {
        _messages[idx] = _messages[idx].copyWith(
          text: _messages[idx].text.isEmpty
              ? 'Response interrupted.'
              : _messages[idx].text,
          isStreaming: false,
        );
      }
      _activeAiMsgId = null;
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _resetChat() {
    if (_isStreaming) return;
    setState(() {
      widget.aiService.clearChatHistory();
      _messages.add(
        AiChatMessage(
          id: 'initial',
          text:
              'Hello! I am your **Buck AI Financial Advisor**. Ask me anything about your spending, budget, or financial goals.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _sendMessage(String text) async {
    final question = text.trim();
    if (question.isEmpty || _isStreaming) return;

    _inputController.clear();

    final userMsg = AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: question,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final aiMsgId = (DateTime.now().microsecondsSinceEpoch + 1).toString();
    final aiPlaceholder = AiChatMessage(
      id: aiMsgId,
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    _activeAiMsgId = aiMsgId;
    setState(() {
      _messages.add(userMsg);
      _messages.add(aiPlaceholder);
      _isStreaming = true;
    });
    _scrollToBottom();

    final buffer = StringBuffer();
    final completer = Completer<void>();

    _activeStreamSub = widget.aiService
        .streamChat(question, history: List<AiChatMessage>.from(_messages))
        .listen(
      (delta) {
        buffer.write(delta);
        final idx = _messages.indexWhere((m) => m.id == aiMsgId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(text: buffer.toString());
        }
        if (mounted) {
          setState(() {});
          _scrollToBottom();
        }
      },
      onError: (Object e) {
        final friendlyError = e is BuckAiException
            ? e.message
            : 'Sorry, I encountered an issue analyzing your finances. Please try again.';
        final idx = _messages.indexWhere((m) => m.id == aiMsgId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            text: buffer.isEmpty ? friendlyError : buffer.toString(),
            isStreaming: false,
          );
        }
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
    _activeStreamSub = null;
    if (_activeAiMsgId == aiMsgId) {
      _activeAiMsgId = null;
    }

    final idx = _messages.indexWhere((m) => m.id == aiMsgId);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(
        text: _messages[idx].text.isEmpty
            ? 'Sorry, I could not generate a response right now.'
            : _messages[idx].text,
        isStreaming: false,
      );
    }
    if (mounted) {
      setState(() {
        _isStreaming = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF140B07),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.glassCardBorder, width: 1.5),
          left: BorderSide(color: AppColors.glassCardBorder, width: 0.5),
          right: BorderSide(color: AppColors.glassCardBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(context),
              const Divider(color: AppColors.subtleDivider, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageItem(msg);
                  },
                ),
              ),
              if (_messages.length <= 2 && !_isStreaming) _buildQuickPrompts(),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  AppColors.gradientOrangeStart,
                  AppColors.gradientOrangeEnd,
                ],
              ),
            ),
            child: SvgPicture.asset(
              'assets/icons/sparkles.svg',
              width: 18,
              height: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUCK AI ADVISOR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textAccent,
                  ),
                ),
                Text(
                  'Ask Financial Questions',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cardTitle,
                  ),
                ),
              ],
            ),
          ),
          if (_messages.length > 1)
            IconButton(
              tooltip: 'Clear chat',
              icon: const Icon(
                Icons.refresh,
                color: AppColors.textSecondary,
                size: 18,
              ),
              onPressed: _isStreaming ? null : _resetChat,
            ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(AiChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.gradientOrangeStart,
                    AppColors.gradientOrangeEnd,
                  ],
                ),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primaryOrange.withValues(alpha: 0.9)
                    : const Color(0xFF22130C),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.cardBorder.withValues(alpha: 0.25)),
              ),
              child: msg.isStreaming && msg.text.isEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Buck AI is thinking...',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : isUser
                      ? Text(
                          msg.text,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.45,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : AiMarkdownText(text: msg.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return ActionChip(
            label: Text(
              prompt,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: const Color(0xFF251610),
            side: BorderSide(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => _sendMessage(prompt),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_isStreaming,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ask financial advisor...',
                hintStyle: GoogleFonts.inter(
                  color: AppColors.placeholderText,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFF1D0E08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryOrange),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isStreaming ? AppColors.trackBrown : AppColors.primaryOrange,
            ),
            child: IconButton(
              icon: _isStreaming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              onPressed: _isStreaming
                  ? null
                  : () => _sendMessage(_inputController.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight inline markdown renderer for AI chat responses.
///
/// Supports `**bold**`, `*italic*`, `` `code` ``, and bulleted list lines (`- ` or `* `).
class AiMarkdownText extends StatelessWidget {
  final String text;

  const AiMarkdownText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.inter(
      fontSize: 13,
      height: 1.48,
      color: Colors.white,
      fontWeight: FontWeight.w400,
    );
    final boldStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.lightPeach,
    );
    final italicStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
    final codeStyle = GoogleFonts.jetBrainsMono(
      fontSize: 12,
      color: AppColors.peachAccent,
      backgroundColor: const Color(0xFF160B06),
    );

    final lines = text.split('\n');
    final children = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trimLeft();
      if (trimmed.isEmpty) {
        if (i > 0 && i < lines.length - 1) {
          children.add(const SizedBox(height: 6));
        }
        continue;
      }

      final isBullet = trimmed.startsWith('- ') || trimmed.startsWith('* ');
      final content = isBullet ? trimmed.substring(2) : rawLine;

      final spans = _parseInlineSpans(
        content,
        baseStyle: baseStyle,
        boldStyle: boldStyle,
        italicStyle: italicStyle,
        codeStyle: codeStyle,
      );

      if (isBullet) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: boldStyle),
                Expanded(child: Text.rich(TextSpan(children: spans))),
              ],
            ),
          ),
        );
      } else {
        children.add(Text.rich(TextSpan(children: spans)));
      }
    }

    if (children.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static List<TextSpan> _parseInlineSpans(
    String input, {
    required TextStyle baseStyle,
    required TextStyle boldStyle,
    required TextStyle italicStyle,
    required TextStyle codeStyle,
  }) {
    final spans = <TextSpan>[];
    final tokenRegex = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\*([^*]+)\*');
    var lastIndex = 0;

    for (final match in tokenRegex.allMatches(input)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: input.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(text: match.group(1), style: boldStyle));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(text: match.group(2), style: codeStyle));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(text: match.group(3), style: italicStyle));
      }
      lastIndex = match.end;
    }

    if (lastIndex < input.length) {
      spans.add(TextSpan(
        text: input.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }
}
