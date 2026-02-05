import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final List<_TerminalEntry> _history = [];
  final List<String> _commandHistory = [];
  int _historyIndex = -1;
  String _draftCommand = '';
  bool _isRunning = false;
  String _currentDir = '~';
  String _prompt = '';
  bool _isCompleting = false;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _horizontalController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final device = context.read<DeviceProvider>().selectedDevice;
      final ssh = context.read<DeviceProvider>().sshService;
      final pwd = await ssh.executeCommand('pwd');
      if (!mounted) return;
      setState(() {
        _currentDir = pwd.trim().isEmpty ? '~' : pwd.trim();
        _prompt = '${device?.username ?? 'user'}@${device?.host ?? 'server'}';
      });
    } catch (_) {}
  }

  Future<void> _runCommand([String? preset]) async {
    if (_isRunning) return;
    final command = (preset ?? _controller.text).trim();
    if (command.isEmpty) return;

    setState(() {
      _isRunning = true;
      _historyIndex = -1;
      _draftCommand = '';
      _history.add(
        _TerminalEntry(
          prompt: _prompt,
          directory: _currentDir,
          command: command,
          output: '',
        ),
      );
    });

    try {
      final ssh = context.read<DeviceProvider>().sshService;
      if (command == 'cd' || command.startsWith('cd ')) {
        final target = command == 'cd' ? '~' : command.substring(3).trim();
        final resolved = await ssh.executeCommand(
          "cd '$_currentDir' && cd $target && pwd",
        );
        _currentDir = resolved.trim().isEmpty ? _currentDir : resolved.trim();
        _history[_history.length - 1] = _history.last.copyWith(output: '');
      } else {
        final output = await ssh.executeCommandInDir(_currentDir, command);
        _history[_history.length - 1] = _history.last.copyWith(
          output: output,
        );
      }
      if (!_commandHistory.contains(command)) {
        _commandHistory.add(command);
      }
    } catch (e) {
      _history[_history.length - 1] =
          _history.last.copyWith(output: 'Ошибка: $e', isError: true);
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
        _controller.clear();
        _suggestions = [];
      });
      _scrollToBottom();
      _inputFocus.requestFocus();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final entry = _history[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TerminalPromptLine(
                          prompt: entry.prompt,
                          directory: entry.directory,
                          command: entry.command,
                        ),
                        if (entry.output.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _TerminalOutputBlock(
                            controller: _horizontalController,
                            text: entry.output,
                            isError: entry.isError,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Shortcuts(
                  shortcuts: {
                    LogicalKeySet(LogicalKeyboardKey.arrowUp): const _HistoryUpIntent(),
                    LogicalKeySet(LogicalKeyboardKey.arrowDown): const _HistoryDownIntent(),
                    LogicalKeySet(LogicalKeyboardKey.tab): const _TabCompleteIntent(),
                  },
                  child: Actions(
                    actions: {
                      _HistoryUpIntent: CallbackAction<_HistoryUpIntent>(
                        onInvoke: (_) {
                          _historyUp();
                          return null;
                        },
                      ),
                      _HistoryDownIntent: CallbackAction<_HistoryDownIntent>(
                        onInvoke: (_) {
                          _historyDown();
                          return null;
                        },
                      ),
                      _TabCompleteIntent: CallbackAction<_TabCompleteIntent>(
                        onInvoke: (_) {
                          _handleTabCompletion();
                          return null;
                        },
                      ),
                    },
                    child: Focus(
                      autofocus: true,
                      child: TextField(
                        controller: _controller,
                        focusNode: _inputFocus,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFE5E7EB),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0B0F14),
                          hintText: '',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: _InlinePrompt(prompt: _prompt, directory: _currentDir),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF1F2937)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                        onChanged: (value) {
                          if (_historyIndex == -1) {
                            _draftCommand = value;
                          }
                          if (_suggestions.isNotEmpty) {
                            setState(() => _suggestions = []);
                          }
                        },
                        onSubmitted: (_) => _runCommand(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _suggestions
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              item,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            onPressed: () => _insertSuggestion(item),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _historyUp() {
    if (_commandHistory.isEmpty) return;
    if (_historyIndex == -1) {
      _draftCommand = _controller.text;
      _historyIndex = _commandHistory.length - 1;
    } else if (_historyIndex > 0) {
      _historyIndex -= 1;
    }
    _controller.text = _commandHistory[_historyIndex];
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  void _historyDown() {
    if (_commandHistory.isEmpty) return;
    if (_historyIndex == -1) return;
    if (_historyIndex < _commandHistory.length - 1) {
      _historyIndex += 1;
      _controller.text = _commandHistory[_historyIndex];
    } else {
      _historyIndex = -1;
      _controller.text = _draftCommand;
    }
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  Future<void> _handleTabCompletion() async {
    if (_isRunning || _isCompleting) return;
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.baseOffset < 0) return;
    final cursor = selection.baseOffset;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);

    final match = RegExp(r'([^\s]*)$').firstMatch(before);
    if (match == null) return;
    final token = match.group(1) ?? '';

    String baseDir = '';
    String prefix = token;
    if (token.contains('/')) {
      final idx = token.lastIndexOf('/');
      baseDir = token.substring(0, idx + 1);
      prefix = token.substring(idx + 1);
    }

    if (baseDir.contains(' ') || prefix.contains(' ')) return;

    _isCompleting = true;
    try {
      final ssh = context.read<DeviceProvider>().sshService;
      List<String> candidates = [];
      if (token.isEmpty) {
        final output = await ssh.executeCommand(
          "cd '$_currentDir' && ls -1a 2>/dev/null",
        );
        candidates = _splitCandidates(output);
      } else if (token.contains('/')) {
        final output = await ssh.executeCommand(
          "cd '$_currentDir' && ls -1a ${baseDir}${prefix}* 2>/dev/null",
        );
        candidates = _splitCandidates(output);
      } else {
        final escaped = prefix.replaceAll("'", "'\"'\"'");
        final output = await ssh.executeCommand(
          "bash -lc \"compgen -c -- '$escaped' | sort -u\" 2>/dev/null",
        );
        candidates = _splitCandidates(output);
        if (candidates.isEmpty) {
          final files = await ssh.executeCommand(
            "cd '$_currentDir' && ls -1a ${baseDir}${prefix}* 2>/dev/null",
          );
          candidates = _splitCandidates(files);
        }
      }
      if (candidates.length > 200) {
        candidates = candidates.take(200).toList();
      }
      if (candidates.isEmpty) return;

      if (candidates.length == 1) {
        final completed = '${baseDir}${candidates.first}';
        final newText = before.replaceRange(
          before.length - token.length,
          before.length,
          completed,
        );
        _controller.text = '$newText$after';
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
        setState(() => _suggestions = []);
        return;
      }

      final common = _commonPrefix(candidates);
      if (common.length > prefix.length) {
        final completed = '${baseDir}${common}';
        final newText = before.replaceRange(
          before.length - token.length,
          before.length,
          completed,
        );
        _controller.text = '$newText$after';
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
        setState(() => _suggestions = candidates);
        return;
      }

      setState(() => _suggestions = candidates);
    } catch (_) {
    } finally {
      _isCompleting = false;
    }
  }

  List<String> _splitCandidates(String output) {
    return output
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _insertSuggestion(String value) {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.baseOffset < 0) return;
    final cursor = selection.baseOffset;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final match = RegExp(r'([^\s]*)$').firstMatch(before);
    if (match == null) return;
    final token = match.group(1) ?? '';
    final newText = before.replaceRange(
      before.length - token.length,
      before.length,
      value,
    );
    _controller.text = '$newText$after';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    setState(() => _suggestions = []);
    _inputFocus.requestFocus();
  }

  String _commonPrefix(List<String> items) {
    if (items.isEmpty) return '';
    var prefix = items.first;
    for (final item in items.skip(1)) {
      while (!item.startsWith(prefix)) {
        if (prefix.isEmpty) return '';
        prefix = prefix.substring(0, prefix.length - 1);
      }
    }
    return prefix;
  }
}

class _TerminalEntry {
  final String prompt;
  final String directory;
  final String command;
  final String output;
  final bool isError;

  _TerminalEntry({
    required this.prompt,
    required this.directory,
    required this.command,
    required this.output,
    this.isError = false,
  });

  _TerminalEntry copyWith({String? output, bool? isError}) {
    return _TerminalEntry(
      prompt: prompt,
      directory: directory,
      command: command,
      output: output ?? this.output,
      isError: isError ?? this.isError,
    );
  }
}

class _HistoryUpIntent extends Intent {
  const _HistoryUpIntent();
}

class _HistoryDownIntent extends Intent {
  const _HistoryDownIntent();
}

class _TabCompleteIntent extends Intent {
  const _TabCompleteIntent();
}

class _TerminalPromptLine extends StatelessWidget {
  final String prompt;
  final String directory;
  final String command;

  const _TerminalPromptLine({
    required this.prompt,
    required this.directory,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    const promptStyle = TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: Color(0xFF22C55E),
    );
    const dirStyle = TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: Color(0xFF60A5FA),
    );
    const cmdStyle = TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: Color(0xFFE5E7EB),
    );

    return RichText(
      text: TextSpan(
        style: cmdStyle,
        children: [
          TextSpan(text: prompt, style: promptStyle),
          const TextSpan(text: ':'),
          TextSpan(text: directory, style: dirStyle),
          const TextSpan(text: r' $ '),
          TextSpan(text: command),
        ],
      ),
    );
  }
}

class _TerminalOutputBlock extends StatelessWidget {
  final ScrollController controller;
  final String text;
  final bool isError;

  const _TerminalOutputBlock({
    required this.controller,
    required this.text,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final outputStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      color: isError ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
      height: 1.35,
    );

    return Scrollbar(
      controller: controller,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          text,
          style: outputStyle,
          textWidthBasis: TextWidthBasis.longestLine,
          maxLines: null,
        ),
      ),
    );
  }
}

class _InlinePrompt extends StatelessWidget {
  final String prompt;
  final String directory;

  const _InlinePrompt({
    required this.prompt,
    required this.directory,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        children: [
          TextSpan(
            text: prompt,
            style: const TextStyle(
              color: Color(0xFF22C55E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(
            text: ':',
            style: TextStyle(color: Color(0xFFE5E7EB)),
          ),
          TextSpan(
            text: directory,
            style: const TextStyle(
              color: Color(0xFF60A5FA),
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(
            text: r' $ ',
            style: TextStyle(color: Color(0xFFE5E7EB)),
          ),
        ],
      ),
    );
  }
}
