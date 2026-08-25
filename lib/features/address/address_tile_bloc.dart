import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wallet_test/features/address/address_repository.dart';

sealed class AddressTileEvent {
  const AddressTileEvent();

  @override
  String toString() => 'AddressTileEvent()';
}

final class CopyTapped extends AddressTileEvent {
  const CopyTapped(this.address);

  final String address;

  @override
  String toString() => 'CopyTapped(address: $address)';
}

final class ResetCopied extends AddressTileEvent {
  const ResetCopied();

  @override
  String toString() => 'ResetCopied()';
}

final class AddressTileState {
  const AddressTileState({
    this.copied = false,
    this.error,
  });

  final bool copied;
  final String? error;

  AddressTileState copyWith({
    bool? copied,
    String? error,
  }) {
    return AddressTileState(
      copied: copied ?? this.copied,
      error: error,
    );
  }
}

class AddressTileBloc extends Bloc<AddressTileEvent, AddressTileState> {
  AddressTileBloc({
    required IAddressRepository repository,
  })  : _repository = repository,
        super(const AddressTileState()) {
    on<AddressTileEvent>(
      (event, emit) => switch (event) {
        CopyTapped() => _onCopyTapped(event, emit),
        ResetCopied() => _onResetCopied(event, emit),
      },
    );
  }

  final IAddressRepository _repository;
  Timer? _resetTimer;

  Future<void> _onCopyTapped(
    CopyTapped event,
    Emitter<AddressTileState> emit,
  ) async {
    emit(const AddressTileState());

    try {
      await _repository.copyAddress(event.address);

      emit(const AddressTileState(copied: true));

      _resetTimer?.cancel();
      _resetTimer = null;
      _resetTimer = Timer(
        const Duration(milliseconds: 1500),
        () => add(const ResetCopied()),
      );
    } catch (_) {
      emit(const AddressTileState(error: 'copy_failed'));
    }
  }

  Future<void> _onResetCopied(
    ResetCopied event,
    Emitter<AddressTileState> emit,
  ) async {
    emit(const AddressTileState());
  }

  @override
  Future<void> close() {
    _resetTimer?.cancel();
    _resetTimer = null;
    return super.close();
  }
}
