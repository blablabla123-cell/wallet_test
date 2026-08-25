import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wallet_test/features/cards/card_issuer.dart';

sealed class CardIssueEvent {
  const CardIssueEvent();

  @override
  String toString() => 'CardIssueEvent()';
}

final class IssueTapped extends CardIssueEvent {
  const IssueTapped(this.request);

  final CardIssueRequest request;
}

final class CardIssueState {
  const CardIssueState({
    this.issuing = false,
    this.error,
  });

  final bool issuing;
  final String? error;
}

class CardIssueBloc extends Bloc<CardIssueEvent, CardIssueState> {
  CardIssueBloc({
    required ICardIssuer issuer,
  })  : _issuer = issuer,
        super(const CardIssueState()) {
    on<CardIssueEvent>(
      (event, emit) => switch (event) {
        IssueTapped() => _onIssueTapped(event, emit),
      },
    );
  }

  final ICardIssuer _issuer;

  Future<void> _onIssueTapped(
    IssueTapped event,
    Emitter<CardIssueState> emit,
  ) async {
    emit(const CardIssueState(issuing: true));

    try {
      await _issuer.issue(event.request);
      emit(const CardIssueState());
    } catch (_) {
      emit(const CardIssueState(error: 'issue_failed'));
    }
  }
}
