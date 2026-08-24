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

  final ApiClient _api;
  final ITransferRepository _repository;

  Future<TransferStatus> sync(
    Transfer transfer, {
    CancelToken? cancelToken,
  }) async {
    final idempotencyKey =
        '${transfer.network.toLowerCase()}:${transfer.txHash}';

    DioException? lastRetryableError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _api.dio.get(
          '/v1/transfers/${transfer.txHash}/status',
          cancelToken: cancelToken,
          options: Options(
            headers: <String, String>{
              'Idempotency-Key': idempotencyKey,
            },
          ),
        );

        final status = TransferStatus.fromName(
          response.data['status'] as String? ?? 'unknown',
        );

        try {
          await _repository.applyStatus(
            transfer,
            status,
            DateTime.now(),
          );
        } catch (error) {
          throw TransferSyncException(
            code: 'localPersistenceFailed',
            message: error.toString(),
          );
        }

        return status;
      } on DioException catch (error) {
        if (error.type == DioExceptionType.cancel) {
          throw const CancelException();
        }

        final statusCode = error.response?.statusCode;
        final retryable = _isRetryable(error);

        if (!retryable) {
          throw _mapDioException(error);
        }

        lastRetryableError = error;

        if (attempt == 2) {
          if (statusCode == 408 || statusCode == 429) {
            throw const TransferSyncException(code: 'rateLimited');
          }
          if (statusCode == 503) {
            throw const TransferSyncException(code: 'serverUnavailable');
          }
          throw const TransferSyncException(code: 'network');
        }

        await Future<void>.delayed(
          Duration(milliseconds: attempt == 0 ? 200 : 500),
        );

        if (cancelToken?.isCancelled ?? false) {
          throw const CancelException();
        }
      }
    }

    throw _mapDioException(lastRetryableError!);
  }

  bool _isRetryable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      case DioExceptionType.badResponse:
        return switch (error.response?.statusCode) {
          408 || 429 || 503 => true,
          _ => false,
        };
      default:
        return false;
    }
  }

  TransferSyncException _mapDioException(DioException error) {
    switch (error.response?.statusCode) {
      case 401:
        return const TransferSyncException(code: 'unauthorized');
      case 404:
        return const TransferSyncException(code: 'notFound');
      case 409:
        return const TransferSyncException(code: 'conflict');
      case 408:
      case 429:
        return const TransferSyncException(code: 'rateLimited');
      case 503:
        return const TransferSyncException(code: 'serverUnavailable');
      case 500:
        return const TransferSyncException(code: 'internal');
      default:
        return const TransferSyncException(code: 'network');
    }
  }
}
