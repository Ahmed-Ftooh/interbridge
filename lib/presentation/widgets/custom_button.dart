import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    this.text,
    required this.onTap,
    this.color,
    this.width,
    this.height,
    this.margin,
    this.textStyle,
    this.borderRadius,
    this.isLoading = false,
    this.child,
  }) : assert(
         text != null || child != null,
         'Either text or child must be provided',
       );

  final Color? color;
  final String? text;
  final void Function() onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final TextStyle? textStyle;
  final BorderRadius? borderRadius;
  final bool isLoading;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? AppSize.s50,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? ColorManager.primary,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        ),
        onPressed: isLoading ? null : onTap,
        child:
            isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : child ??
                    Text(
                      text!,
                      style:
                          textStyle ??
                          Theme.of(context).textTheme.headlineLarge,
                    ),
      ),
    );
  }
}
