import 'package:flutter/material.dart';
import 'package:website/breakpoints.dart';
import 'package:website/homepage/call_to_action.dart';
import 'package:website/homepage/editor_video_showcase.dart';
import 'package:website/homepage/featured_editor.dart';
import 'package:website/homepage/features.dart';
import 'package:website/homepage/footer.dart';
import 'package:website/homepage/header.dart';
import 'package:website/homepage/inside_the_toolbox.dart';

class HomePage extends StatelessWidget {
  const HomePage();

  @override
  Widget build(BuildContext context) {
    final isSingleColumnLayout = Breakpoints.collapsedNavigation(context);

    return Scaffold(
      // TODO: move magic number to named constant
      backgroundColor: const Color(0xFF003F51),
      body: DrawerLayout(
        isNavigationCollapsed: isSingleColumnLayout,
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 18,
            height: 1.5,
            color: Colors.white,
          ),
          child: _buildContent(
            isSingleColumnLayout: isSingleColumnLayout,
          ),
        ),
      ),
    );
  }

  Widget _buildContent({required bool isSingleColumnLayout}) {
    return Scrollbar(
      child: SingleChildScrollView(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/background.png',
                fit: BoxFit.cover,
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 30),
                Header(
                  displayCollapsedNavigation: isSingleColumnLayout,
                ),
                SizedBox(height: isSingleColumnLayout ? 16 : 52),
                _buildFeaturedEditor(
                  displayMode: isSingleColumnLayout ? DisplayMode.compact : DisplayMode.wide,
                ),
                SizedBox(height: isSingleColumnLayout ? 92 : 135),
                Container(
                  color: const Color(0xFF003F51),
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      const Features(),
                      EditorVideoShowcase(
                        url: 'https://www.youtube.com/embed/nZ9pWg_QOwM',
                        isCompact: isSingleColumnLayout,
                      ),
                      const InsideTheToolbox(),
                    ],
                  ),
                ),
                const CallToAction(),
                const Footer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedEditor({required DisplayMode displayMode}) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800).tighten(
          // TODO: move magic numbers to named constants
          height: displayMode == DisplayMode.compact ? 400 : 632,
        ),
        margin: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: displayMode == DisplayMode.compact ? 16 : 0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.79),
                blurRadius: 75,
              ),
            ],
          ),
          child: FeaturedEditor(
            displayMode: displayMode,
          ),
        ),
      ),
    );
  }
}
