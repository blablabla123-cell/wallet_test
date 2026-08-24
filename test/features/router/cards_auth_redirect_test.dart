import 'package:flutter_test/flutter_test.dart';

import 'package:wallet_test/features/router/cards_auth_redirect.dart';

void main() {
  test('unauthenticated cards deep link redirects to onboarding with encoded next',
      () {
    final result = cardsAuthRedirect(
      Uri.parse('/cards/card_1/issue?step=2'),
      false,
    );

    expect(
      result,
      '/onboarding?next=%2Fcards%2Fcard_1%2Fissue%3Fstep%3D2',
    );
  });

  test('authenticated onboarding restores a safe cards deep link', () {
    final result = cardsAuthRedirect(
      Uri.parse(
        '/onboarding?next=%2Fcards%2Fcard_1%2Fissue%3Fstep%3D2',
      ),
      true,
    );

    expect(result, '/cards/card_1/issue?step=2');
  });

  test('external next is rejected', () {
    final result = cardsAuthRedirect(
      Uri.parse(
        '/onboarding?next=https%3A%2F%2Fevil.com',
      ),
      true,
    );

    expect(result, '/cards');
  });

  test('unauthenticated onboarding does not redirect', () {
    expect(
      cardsAuthRedirect(Uri.parse('/onboarding'), false),
      isNull,
    );
  });

  test('authenticated cards route does not redirect', () {
    expect(
      cardsAuthRedirect(Uri.parse('/cards'), true),
      isNull,
    );
  });

  test('empty next falls back to cards', () {
    expect(
      cardsAuthRedirect(Uri.parse('/onboarding?next='), true),
      '/cards',
    );
  });
}
