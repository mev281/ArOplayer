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
    return Scaffold(
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: kNeonSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kNeonBorder),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: kNeonCyanGlow,
                        blurRadius: 32,
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
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: kNeonCyan,
                          shadows: <Shadow>[
                            Shadow(color: kNeonCyanGlow, blurRadius: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('Kaynak seçin ve yayına başlayın'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF9A9AAB)),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _TypeCard(
                              selected: _type == SourceType.m3u,
                              icon: Icons.link_rounded,
                              title: t('M3U Linki'),
                              subtitle: t('Hazır liste adresi'),
                              onTap: () {
                                setState(() {
                                  _type = SourceType.m3u;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TypeCard(
                              selected: _type == SourceType.xtream,
                              icon: Icons.dns_rounded,
                              title: 'Xtream Codes',
                              subtitle: t('Sunucu bilgileri'),
                              onTap: () {
                                setState(() {
                                  _type = SourceType.xtream;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_type == SourceType.m3u)
                        _FocusFrame(
                          child: TextField(
                            controller: _m3uController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: t('M3U Linki'),
                              hintText: 'http://ornek.com/liste.m3u',
                              prefixIcon: const Icon(Icons.link_rounded),
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _FocusFrame(
                              child: TextField(
                                controller: _hostController,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: t('Sunucu URL'),
                                  hintText: 'http://sunucu.com:8080',
                                  prefixIcon: const Icon(Icons.dns_rounded),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FocusFrame(
                              child: TextField(
                                controller: _userController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: t('Kullanıcı Adı'),
                                  prefixIcon: const Icon(Icons.person_rounded),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FocusFrame(
                              child: TextField(
                                controller: _passController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: t('Şifre'),
                                  prefixIcon: const Icon(Icons.lock_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 28),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      Text(
                        t('Ebeveyn Kontrolü'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t(
                          'Yetişkin kategorilerini gizlemek için 4 haneli PIN belirleyin.',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8A9B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FocusFrame(
                        child: TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 4,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: InputDecoration(
                            labelText: t('PIN (4 hane)'),
                            prefixIcon: const Icon(Icons.pin_rounded),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _FocusFrame(
                        child: SwitchListTile(
                          value: _hideAdult,
                          onChanged: (value) {
                            setState(() {
                              _hideAdult = value;
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(
                            t('Yetişkin kategorilerini gizle'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _FocusFrame(
                        child: FilledButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  _save();
                                },
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
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
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? kNeonCyan : kNeonBorder,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  color: selected ? kNeonCyan : const Color(0xFF9A9AAB),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? kNeonCyan : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A8A9B),
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
