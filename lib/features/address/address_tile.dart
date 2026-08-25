import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:wallet_test/core/theme/app_tokens.dart';
import 'package:wallet_test/features/address/address_display.dart';
import 'package:wallet_test/features/address/address_tile_bloc.dart';

class AddressTile extends StatefulWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.network,
  });

  final String address;
  final String network;

  @override
  State<AddressTile> createState() => _AddressTileState();
}

class _AddressTileState extends State<AddressTile> {
  late final AddressTileBloc _bloc = GetIt.instance<AddressTileBloc>();

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);

    return Container(
      height: AppTokens.cellHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.horizontalPadding,
      ),
      color: AppTokens.surface,
      child: BlocBuilder<AddressTileBloc, AddressTileState>(
        bloc: _bloc,
        builder: (context, state) {
          final IconData icon;
          final Color iconColor;

          switch (state) {
            case const AddressTileState(error: null, copied: false):
              icon = Icons.copy;
              iconColor = AppTokens.textSecondary;
              break;
            case const AddressTileState(error: null, copied: true):
              icon = Icons.check;
              iconColor = AppTokens.success;
              break;
            case AddressTileState(error: final String? _):
              icon = Icons.error_outline;
              iconColor = AppTokens.danger;
              break;
          }

          return Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentGeometry.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.network,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTokens.verticalGap),
                      Text(
                        formatAddressForCell(
                          widget.address,
                          textScaleFactor,
                        ),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTokens.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.gapTextIcon),
              SizedBox(
                width: AppTokens.tapTarget,
                height: AppTokens.tapTarget,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppTokens.tapTarget,
                    minHeight: AppTokens.tapTarget,
                  ),
                  onPressed: () => _bloc.add(CopyTapped(widget.address)),
                  icon: Icon(
                    icon,
                    size: AppTokens.iconSize,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
