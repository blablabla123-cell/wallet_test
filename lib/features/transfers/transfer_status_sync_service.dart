import 'package:dio/dio.dart';

import 'package:wallet_test/core/errors/app_exception.dart';
import 'package:wallet_test/core/network/api_client.dart';
import 'package:wallet_test/features/transfers/transfer.dart';
import 'package:wallet_test/features/transfers/transfer_repository.dart';

class TransferStatusSyncService {
  const TransferStatusSyncService({
    required ApiClient api,
    required ITransferRepository repository,
  })  : _api = api,
        _repository = repository;

  static const _maxAttempts = 3;
  static const _retryDelays = [
    Duration(milliseconds: 200),
    Duration(milliseconds: 500),
  ];
  static const _retryableStatusCodes = {408, 429, 503};

  final ApiClient _api;
  final ITransferRepository _repository;

  Future<TransferStatus> sync(
    Transfer transfer, {
    CancelToken? cancelToken,
  }) async {
    final idempotencyKey =
        '${transfer.network.toLowerCase()}:${transfer.txHash}';

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final status = await _fetchStatus(
          transfer.txHash,
          idempotencyKey,
          cancelToken,
        );
        await _persist(transfer, status);
        return status;
      } on DioException catch (error) {
        if (error.type == DioExceptionType.cancel) {
          throw const CancelException();
        }

        final canRetry = _isRetryable(error) && attempt < _maxAttempts - 1;
        if (!canRetry) {
          throw _mapDioException(error);
        }

        await Future<void>.delayed(_retryDelays[attempt]);
        if (cancelToken?.isCancelled ?? false) {
          throw const CancelException();
        }
      }
    }

    throw const TransferSyncException(code: 'network');
  }

  Future<TransferStatus> _fetchStatus(
    String txHash,
    String idempotencyKey,
    CancelToken? cancelToken,
  ) async {
    final response = await _api.dio.get(
      '/v1/transfers/$txHash/status',
      cancelToken: cancelToken,
      options: Options(
        headers: <String, String>{
          'Idempotency-Key': idempotencyKey,
        },
      ),
    );

    return TransferStatus.fromName(
      response.data['status'] as String? ?? TransferStatus.unknown.name,
    );
  }

  Future<void> _persist(Transfer transfer, TransferStatus status) async {
    try {
      await _repository.applyStatus(transfer, status, DateTime.now());
    } catch (error) {
      throw TransferSyncException(
        code: 'localPersistenceFailed',
        message: error.toString(),
      );
    }
  }

  bool _isRetryable(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        true,
      DioExceptionType.badResponse =>
        _retryableStatusCodes.contains(error.response?.statusCode),
      _ => false,
    };
  }

  TransferSyncException _mapDioException(DioException error) {
    return TransferSyncException(
      code: switch (error.response?.statusCode) {
        401 => 'unauthorized',
        404 => 'notFound',
        409 => 'conflict',
        408 || 429 => 'rateLimited',
        503 => 'serverUnavailable',
        500 => 'internal',
        _ => 'network',
      },
    );
  }
}
