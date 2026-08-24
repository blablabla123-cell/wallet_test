import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wallet_test/core/dev_stubs/in_memory_transfer_repository.dart';
import 'package:wallet_test/core/errors/app_exception.dart';
import 'package:wallet_test/core/network/api_client.dart';
import 'package:wallet_test/features/transfers/transfer.dart';
import 'package:wallet_test/features/transfers/transfer_status_sync_service.dart';
import '../../fakes/fake_http_client_adapter.dart';

Transfer _transfer({String network = 'Ethereum'}) {
  return Transfer(
    id: 'transfer-1',
    network: network,
    txHash: '0x1234abcd',
  );
}

void main() {
  test('429 then 200 retries once and persists once', () async {
    final adapter = FakeHttpClientAdapter([
      HttpOutcome(429),
      HttpOutcome(200, body: {'status': 'confirmed'}),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = InMemoryTransferRepository();
    final service = TransferStatusSyncService(
      api: ApiClient(dio: dio),
      repository: repository,
    );

    final result = await service.sync(_transfer());

    expect(adapter.calls, hasLength(2));
    expect(repository.applyCalls, 1);
    expect(result, TransferStatus.confirmed);
  });

  test('401 is not retried and maps to unauthorized', () async {
    final adapter = FakeHttpClientAdapter([HttpOutcome(401)]);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = InMemoryTransferRepository();
    final service = TransferStatusSyncService(
      api: ApiClient(dio: dio),
      repository: repository,
    );

    await expectLater(
      service.sync(_transfer()),
      throwsA(
        isA<TransferSyncException>().having(
          (e) => e.code,
          'code',
          'unauthorized',
        ),
      ),
    );

    expect(adapter.calls, hasLength(1));
    expect(repository.applyCalls, 0);
  });

  test('500 is not retried and maps to internal', () async {
    final adapter = FakeHttpClientAdapter([HttpOutcome(500)]);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = InMemoryTransferRepository();
    final service = TransferStatusSyncService(
      api: ApiClient(dio: dio),
      repository: repository,
    );

    await expectLater(
      service.sync(_transfer()),
      throwsA(
        isA<TransferSyncException>().having(
          (e) => e.code,
          'code',
          'internal',
        ),
      ),
    );

    expect(adapter.calls, hasLength(1));
    expect(repository.applyCalls, 0);
  });

  test('three 429 responses make exactly three calls', () async {
    final adapter = FakeHttpClientAdapter([
      HttpOutcome(429),
      HttpOutcome(429),
      HttpOutcome(429),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = InMemoryTransferRepository();
    final service = TransferStatusSyncService(
      api: ApiClient(dio: dio),
      repository: repository,
    );

    await expectLater(
      service.sync(_transfer()),
      throwsA(
        isA<TransferSyncException>().having(
          (e) => e.code,
          'code',
          'rateLimited',
        ),
      ),
    );

    expect(adapter.calls, hasLength(3));
    expect(repository.applyCalls, 0);
  });

  test('successful HTTP followed by DB failure maps to localPersistenceFailed',
      () async {
    final adapter = FakeHttpClientAdapter([
      HttpOutcome(200, body: {'status': 'confirmed'}),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = InMemoryTransferRepository()..shouldFail = true;
    final service = TransferStatusSyncService(
      api: ApiClient(dio: dio),
      repository: repository,
    );

    await expectLater(
      service.sync(_transfer()),
      throwsA(
        isA<TransferSyncException>().having(
          (e) => e.code,
          'code',
          'localPersistenceFailed',
        ),
      ),
    );

    expect(repository.applyCalls, 1);
  });

  test('Idempotency-Key is stable and uses lowercase network', () async {
    final adapter = FakeHttpClientAdapter([
      HttpOutcome(200, body: {'status': 'confirmed'}),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = InMemoryTransferRepository();
    final service = TransferStatusSyncService(
      api: ApiClient(dio: dio),
      repository: repository,
    );

    await service.sync(_transfer(network: 'ETHEREUM'));

    expect(
      adapter.calls.single.headers['Idempotency-Key'],
      'ethereum:0x1234abcd',
    );
  });

  test('cancelled request does not retry or persist', () async {
    final adapter = FakeHttpClientAdapter([HttpOutcome(200)]);
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = InMemoryTransferRepository();
    final service = TransferStatusSyncService(
      api: ApiClient(dio: dio),
      repository: repository,
    );
    final cancelToken = CancelToken()..cancel();

    await expectLater(
      service.sync(_transfer(), cancelToken: cancelToken),
      throwsA(isA<CancelException>()),
    );

    expect(adapter.calls, isEmpty);
    expect(repository.applyCalls, 0);
  });
}
