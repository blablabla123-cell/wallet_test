import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:wallet_test/features/address/address_repository.dart';
import 'package:wallet_test/features/address/address_tile.dart';
import 'package:wallet_test/features/address/address_tile_bloc.dart';

class _FakeAddressRepository implements IAddressRepository {
  bool shouldFail = false;
  int copyCalls = 0;
  String? lastAddress;

  @override
  Future<void> copyAddress(String address) async {
    copyCalls++;
    lastAddress = address;
    if (shouldFail) {
      throw Exception('copy failed');
    }
  }
}

class _TrackingAddressTileBloc extends AddressTileBloc {
  _TrackingAddressTileBloc({required super.repository});

  int closeCount = 0;

  @override
  Future<void> close() {
    closeCount++;
    return super.close();
  }
}

void main() {
  final getIt = GetIt.instance;
  AddressTileBloc? currentBloc;

  tearDown(() async {
    if (currentBloc != null && !currentBloc!.isClosed) {
      await currentBloc!.close();
    }
    if (getIt.isRegistered<AddressTileBloc>()) {
      await getIt.unregister<AddressTileBloc>();
    }
    if (getIt.isRegistered<IAddressRepository>()) {
      await getIt.unregister<IAddressRepository>();
    }
  });

  Future<({AddressTileBloc bloc, _FakeAddressRepository repository})> setup({
    bool shouldFail = false,
  }) async {
    final repository = _FakeAddressRepository()..shouldFail = shouldFail;
    getIt.registerSingleton<IAddressRepository>(repository);

    final bloc = AddressTileBloc(repository: repository);
    currentBloc = bloc;
    getIt.registerFactory<AddressTileBloc>(() => bloc);

    return (bloc: bloc, repository: repository);
  }

  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddressTile(
            address: '0x1234567890abcdef1234567890abcdef12345678',
            network: 'Ethereum',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the widget', (tester) async {
    await setup();
    await pumpTile(tester);

    expect(find.text('Ethereum'), findsOneWidget);
    expect(find.text('0x123456…5678'), findsOneWidget);
  });

  testWidgets('has no overflow at text scale 2.0', (tester) async {
    await setup();

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: AddressTile(
              address: '0x1234567890abcdef1234567890abcdef12345678',
              network: 'Ethereum',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('copy button calls repository', (tester) async {
    final result = await setup();
    await pumpTile(tester);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(result.repository.copyCalls, 1);
    expect(
      result.repository.lastAddress,
      '0x1234567890abcdef1234567890abcdef12345678',
    );
  });

  testWidgets('successful copy shows copied state and resets after 1500ms', (tester) async {
    final result = await setup();
    await pumpTile(tester);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(result.bloc.state.copied, isTrue);

    await tester.pump(const Duration(milliseconds: 1499));
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byIcon(Icons.copy), findsOneWidget);
    expect(result.bloc.state.copied, isFalse);
  });

  testWidgets('failed copy shows error state', (tester) async {
    await setup(shouldFail: true);
    await pumpTile(tester);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('bloc is closed after dispose', (tester) async {
    final repository = _FakeAddressRepository();
    getIt.registerSingleton<IAddressRepository>(repository);

    final bloc = _TrackingAddressTileBloc(repository: repository);
    currentBloc = bloc;
    getIt.registerFactory<AddressTileBloc>(() => bloc);

    await pumpTile(tester);
    expect(bloc.closeCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(find.byType(AddressTile), findsNothing);
    expect(bloc.closeCount, 1);
  });
}
