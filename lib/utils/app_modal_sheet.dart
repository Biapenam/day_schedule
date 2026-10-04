import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 统一的底部弹窗外观：白色圆角面板 + 平板下限制宽度并居中。
///
/// 需要键盘避让时，请在 [builder] 返回的内容外包一层
/// `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom))`
/// （参考 settings_screen 的口令导入弹窗）。
Future<T?> showAppModalSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 640,
  Color backgroundColor = AppColors.background,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    constraints: BoxConstraints(maxWidth: maxWidth),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: builder,
  );
}
