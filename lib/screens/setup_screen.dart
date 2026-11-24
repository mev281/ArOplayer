import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/l10n.dart';
import '../services/storage_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _m3uController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  SourceType _type = SourceType.m3u;
  bool _hideAdult = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final storage = StorageService.instance;
    _type = storage.sourceType ?? SourceType.m3u;
    _hideAdult = storage.hideAdult;
    final existingPin = storage.pin;
    if (existingPin != null) {
      _pinController.text = existingPin;
    }
    final existingUrl = storage.m3uUrl;
    if (existingUrl != null && _type == SourceType.m3u) {
      _m3uController.text = existingUrl;
    }
  }

  @override
  void dispose() {
    _m3uController.dispose();
    _hostController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final storage = StorageService.instance;
    final pin = _pinController.text.trim();

    if (pin.isNotEmpty && pin.length != 4) {
      _showMessage(t('PIN 4 haneli olmalıdır.'));
      return;
    }

    String url;
    String? host;
    String? username;
    String? password;

    if (_type == SourceType.m3u) {
      url = _m3uController.text.trim();
      if (url.isEmpty) {
        _showMessage(t('M3U linki boş olamaz.'));
        return;
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        _showMessage(t('M3U linki http:// veya https:// ile başlamalıdır.'));
        return;
      }
    } else {
      host = _hostController.text.trim();
      username = _userController.text.trim();
      password = _passController.text;
      if (host.isEmpty || username.isEmpty || password.isEmpty) {
        _showMessage(t('Sunucu adresi, kullanıcı adı ve şifre zorunludur.'));
        return;
      }
      url = StorageService.xtreamToM3u(host, username, password);
    }

    setState(() {
      _saving = true;
    });

    await storage.saveSource(
      type: _type,
      m3uUrl: url,
      host: host,
      username: username,
      password: password,
    );
    if (pin.length == 4) {
      await storage.setPin(pin);
    }
    await storage.setHideAdult(_hideAdult);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const AppLoader()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = (media.size.height / 720).clamp(0.72, 1.0).toDouble();
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: _buildScaffold(),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
    bool last = false,
    int? maxLength,
    List<TextInputFormatter>? formatters,
  }) {
    return _FocusFrame(
      child: _DpadTextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        maxLength: maxLength,
        inputFormatters: formatters,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onSubmitted: last ? _save : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          isDense: true,
          counterText: maxLength == null ? null : '',
        ),
      ),
    );
  }

  Widget _buildScaffold() {
    final fields = <Widget>[
      if (_type == SourceType.m3u)
        _field(
          controller: _m3uController,
          label: t('M3U Linki'),
          hint: 'http://ornek.com/liste.m3u',
          icon: Icons.link_rounded,
          keyboardType: TextInputType.url,
          last: true,
        )
      else ...<Widget>[
        _field(
          controller: _hostController,
          label: t('Sunucu URL'),
          hint: 'http://sunucu.com:8080',
          icon: Icons.dns_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: _field(
                controller: _userController,
                label: t('Kullanıcı Adı'),
                icon: Icons.person_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(
                controller: _passController,
                label: t('Şifre'),
                icon: Icons.lock_rounded,
                obscure: true,
                last: true,
              ),
            ),
          ],
        ),
      ],
    ];
    return Scaffold(
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 560,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: kNeonSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kNeonBorder),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: kNeonCyanGlow,
                          blurRadius: 24,
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'ArOplayer',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: kNeonCyan,
                            shadows: <Shadow>[
                              Shadow(color: kNeonCyanGlow, blurRadius: 14),
                            ],
                          ),
                        ),
                        Text(
                          t('Kaynak seçin ve yayına başlayın'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A9AAB),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _TypeCard(
                                selected: _type == SourceType.m3u,
                                icon: Icons.link_rounded,
                                title: t('M3U Linki'),
                                onTap: () {
                                  setState(() {
                                    _type = SourceType.m3u;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TypeCard(
                                selected: _type == SourceType.xtream,
                                icon: Icons.dns_rounded,
                                title: 'Xtream Codes',
                                onTap: () {
                                  setState(() {
                                    _type = SourceType.xtream;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...fields,
                        const SizedBox(height: 8),
                        Text(
                          t('Ebeveyn Kontrolü'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: _field(
                                controller: _pinController,
                                label: t('PIN (4 hane)'),
                                icon: Icons.pin_rounded,
                                keyboardType: TextInputType.number,
                                obscure: true,
                                last: true,
                                maxLength: 4,
                                formatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: _FocusFrame(
                                child: SwitchListTile(
                                  value: _hideAdult,
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (value) {
                                    setState(() {
                                      _hideAdult = value;
                                    });
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  title: Text(
                                    t('Yetişkin kategorilerini gizle'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _FocusFrame(
                          child: FilledButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    _save();
                                  },
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(t('Kaydet ve Başla')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DpadTextField extends StatefulWidget {
  const _DpadTextField({
    required this.controller,
    required this.decoration,
    required this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.inputFormatters,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onSubmitted;

  @override
  State<_DpadTextField> createState() => _DpadTextFieldState();
}

class _DpadTextFieldState extends State<_DpadTextField> {
  late final FocusNode _node = FocusNode(
    debugLabel: 'setup-field',
    onKeyEvent: _onKey,
  );

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      node.nextFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      node.previousFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _node,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      textInputAction: widget.textInputAction,
      decoration: widget.decoration,
      onSubmitted: (_) {
        if (widget.onSubmitted != null) {
          widget.onSubmitted!();
        } else {
          _node.nextFocus();
        }
      },
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FocusFrame(
      child: Material(
        color: selected ? kNeonCyanSoft : kNeonSurfaceHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? kNeonCyan : kNeonBorder,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? kNeonCyan : const Color(0xFF9A9AAB),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? kNeonCyan : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusFrame extends StatefulWidget {
  const _FocusFrame({required this.child});

  final Widget child;

  @override
  State<_FocusFrame> createState() => _FocusFrameState();
}

class _FocusFrameState extends State<_FocusFrame> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) {
        if (_focused == value) return;
        setState(() {
          _focused = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused ? kNeonCyan : const Color(0x00000000),
            width: 2,
          ),
          boxShadow: _focused
              ? const <BoxShadow>[
                  BoxShadow(
                    color: kNeonCyanGlow,
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: widget.child,
      ),
    );
  }
}
