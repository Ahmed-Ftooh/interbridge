import 'package:flutter/material.dart';

class CustomCardWidget extends StatelessWidget {
  const CustomCardWidget({
    super.key,
    required this.title,
    required this.subTitle,
    required this.icon,
  });
  final String title;
  final String subTitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 50,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        color: Colors.grey[500],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(subTitle, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
