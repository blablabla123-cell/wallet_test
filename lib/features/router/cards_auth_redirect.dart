String? cardsAuthRedirect(Uri uri, bool isAuthed) {
  final path = uri.path;

  final isCardsPath = path == '/cards' || path.startsWith('/cards/');
  final isOnboarding = path == '/onboarding';

  if (!isAuthed && isCardsPath) {
    final location = uri.toString();
    return '/onboarding?next=${Uri.encodeComponent(location)}';
  }

  if (isAuthed && isOnboarding) {
    final next = uri.queryParameters['next'];
    if (next == null || next.isEmpty) {
      return '/cards';
    }

    final decoded = Uri.tryParse(next);
    if (decoded == null) {
      return '/cards';
    }

    final safe = decoded.path == '/cards' ||
        decoded.path.startsWith('/cards/');
    if (!safe || decoded.hasScheme || decoded.hasAuthority) {
      return '/cards';
    }

    return decoded.toString();
  }

  return null;
}
