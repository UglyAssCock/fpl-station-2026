import 'package:flutter/material.dart';

/// Base URL for all Fantasy Premier League API requests (Season 2026/27).
const String kFplBaseUrl = 'https://fantasy.premierleague.com/api/';

/// Single season folder variable for 2026/27 player photos.
/// Change this ONE string if the Premier League updates the CDN folder name.
const String kCurrentSeasonFolder = 'premierleague26';
const String kFallbackSeasonFolder = 'premierleague25';

/// Single constant pattern function for Player Photos using the player's `code`.
String buildPlayerPhotoUrl(int code, {String folder = kCurrentSeasonFolder}) {
  return 'https://resources.premierleague.com/$folder/photos/players/110x140/p$code.png';
}

/// Legacy fallback URL pattern used by Premier League CDN.
String buildLegacyPlayerPhotoUrl(int code) {
  return 'https://resources.premierleague.com/premierleague/photos/players/110x140/p$code.png';
}

/// Club badge URL builder using the club's `code` from bootstrap-static.
String buildClubBadgeUrl(int teamCode) {
  return 'https://resources.premierleague.com/premierleague/badges/70/t$teamCode.png';
}

String buildFallbackClubBadgeUrl(int teamCode) {
  return 'https://resources.premierleague.com/premierleague/badges/t$teamCode.png';
}

/// Widget that loads 2026/27 player photo first, then falls back to 2025/26,
/// then legacy folder, then a clean person icon.
class PlayerPhoto extends StatelessWidget {
  final int playerCode;
  final double width;
  final double height;

  const PlayerPhoto({
    super.key,
    required this.playerCode,
    this.width = 48,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    final primaryUrl = buildPlayerPhotoUrl(playerCode, folder: kCurrentSeasonFolder);
    final secondUrl = buildPlayerPhotoUrl(playerCode, folder: kFallbackSeasonFolder);
    final thirdUrl = buildLegacyPlayerPhotoUrl(playerCode);

    return Image.network(
      primaryUrl,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.network(
          secondUrl,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error2, stackTrace2) {
            return Image.network(
              thirdUrl,
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error3, stackTrace3) {
                return Container(
                  width: width,
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: width * 0.65,
                    color: Colors.grey.shade400,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Widget that loads the club badge from team `code` with fallback.
class ClubBadge extends StatelessWidget {
  final int teamCode;
  final double size;

  const ClubBadge({
    super.key,
    required this.teamCode,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      buildClubBadgeUrl(teamCode),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.network(
          buildFallbackClubBadgeUrl(teamCode),
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error2, stackTrace2) {
            return Icon(
              Icons.shield,
              size: size,
              color: const Color(0xFF6C2BD9),
            );
          },
        );
      },
    );
  }
}

/// Helper for displaying uploaded assets/images/ files with safe fallback if missing.
class AppAssetImage extends StatelessWidget {
  final String fileName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;

  const AppAssetImage({
    super.key,
    required this.fileName,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/$fileName',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
