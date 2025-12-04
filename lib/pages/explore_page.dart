import 'package:flutter/material.dart';
import '../widgets/card_item.dart';
import 'detail_page.dart';

class ExplorePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Explore")),
      body: GridView.builder(
        padding: EdgeInsets.all(12),
        itemCount: 6,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetailPage(villaId: '', villaData: {},)),
            ),
            child: CardItem(),
          );
        },
      ),
    );
  }
}
