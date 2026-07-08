import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      "title": "EL PROPÓSITO",
      "subtitle": "Protegemos tus ahorros y tu identidad",
      "desc": "JOSH Security levanta un muro de contención digital contra llamadas falsas, estafas telefónicas y mensajes tramposos diseñados para vaciar tus cuentas.",
      "icon": "🛡️"
    },
    {
      "title": "LA PROMESA",
      "subtitle": "Un guardián invisible y eficiente",
      "desc": "Monitoreamos las amenazas en segundo plano mediante análisis heurístico local. Cero impacto en el rendimiento de tu celular y mínimo gasto de batería.",
      "icon": "⚡"
    },
    {
      "title": "TRANSPARENCIA RADICAL",
      "subtitle": "Por qué JOSH necesita ser tu Centinela",
      "desc": "Para interceptar fraudes antes de que los abras, requerimos acceso a llamadas y SMS. Tus datos no se venden ni se exponen: se procesan bajo criptografía forense.",
      "icon": "👁️"
    }
  ];

  void _finalizarOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_visto', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _finalizarOnboarding,
                  child: const Text(
                    "SALTAR",
                    style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(slide["icon"]!, style: const TextStyle(fontSize: 80)),
                        const SizedBox(height: 40),
                        Text(
                          slide["title"]!,
                          style: const TextStyle(
                            fontSize: 14, 
                            color: Color(0xFF00E676), 
                            letterSpacing: 3, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          slide["subtitle"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          slide["desc"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: Color(0xFF94A3B8), height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? const Color(0xFF00E676) : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _slides.length - 1) {
                        _finalizarOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFF00E676), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      _currentPage == _slides.length - 1 ? "ENTENDIDO • ACTIVAR" : "SIGUIENTE",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}