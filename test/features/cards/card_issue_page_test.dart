import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:wallet_test/core/dev_stubs/dev_card_issuer.dart';
import 'package:wallet_test/features/cards/card_issue_bloc.dart';
import 'package:wallet_test/features/cards/card_issue_page.dart';
import 'package:wallet_test/features/cards/card_issuer.dart';

class _TrackingCardIssueBloc extends CardIssueBloc {
  _TrackingCardIssueBloc({required super.issuer});

  int closeCount = 0;

  @override
  Future<void> close() {
    closeCount++;
    return super.close();
  }
}

void main() {
  final getIt = GetIt.instance;

  tearDown(() async {
    if (getIt.isRegistered<CardIssueBloc>()) {
      await getIt.unregister<CardIssueBloc>();
    }
    if (getIt.isRegistered<ICardIssuer>()) {
      await getIt.unregister<ICardIssuer>();
    }
  });

  Future<({DevCardIssuer issuer, _TrackingCardIssueBloc bloc})> setup() async {
    final issuer = DevCardIssuer();
    getIt.registerSingleton<ICardIssuer>(issuer);

    final bloc = _TrackingCardIssueBloc(issuer: issuer);
    getIt.registerFactory<CardIssueBloc>(() => bloc);

    return (issuer: issuer, bloc: bloc);
  }

  testWidgets('page renders and dependencies come from GetIt', (tester) async {
    final result = await setup();

    await tester.pumpWidget(
      const MaterialApp(
        home: CardIssuePage(cardId: 'card_1'),
      ),
    );

    expect(find.text('Issue card'), findsOneWidget);
    expect(GetIt.instance<ICardIssuer>(), same(result.issuer));
    expect(GetIt.instance<CardIssueBloc>(), same(result.bloc));
    expect(result.bloc.closeCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(find.byType(CardIssuePage), findsNothing);
    expect(result.bloc.closeCount, 1);
    expect(result.issuer.cancelCalls, 1);
  });

  testWidgets('dispose closes BLoC and cancels pending exactly once',
      (tester) async {
    final result = await setup();

    await tester.pumpWidget(
      const MaterialApp(
        home: CardIssuePage(cardId: 'card_1'),
      ),
    );

    expect(result.bloc.closeCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(find.byType(CardIssuePage), findsNothing);
    expect(result.bloc.closeCount, 1);
    expect(result.issuer.cancelCalls, 1);
  });
}
