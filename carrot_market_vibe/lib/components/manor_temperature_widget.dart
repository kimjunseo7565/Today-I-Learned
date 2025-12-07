import 'package:flutter/material.dart';

class ManorTemperature extends StatelessWidget {
  final double manorTemp;
  final int? level;
  final List<Color> temperColors = [
    Color(0xFF072038),
    Color(0xFF0d3a65),
    Color(0xFF186ec0),
    Color(0xFF38b24d),
    Color(0xFFFFad13),
    Color(0xFFF76707),
  ];
  
  ManorTemperature({Key? key, required this.manorTemp}) : level = _calcTempLevel(manorTemp), super(key: key);

  static int _calcTempLevel(double manorTemp) {
    if(manorTemp <= 20) {
      return 0;
    } else if (manorTemp > 20 && manorTemp <= 32) {
      return 1;
    } else if (manorTemp > 32 && manorTemp <= 36.5) {
      return 2;
    } else if (manorTemp > 36.5 && manorTemp <= 40) {
      return 3;
    } else if (manorTemp > 40 && manorTemp <= 50) {
      return 4;
    } else if (manorTemp > 50) {
      return 5;
    }
    return 2;
  }

  Widget _makeTempLabelAndBar() {
    return Container(
      width: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${manorTemp}℃",
            style: TextStyle(
              color: temperColors[level ?? 2],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 6,
              color: Colors.black.withOpacity(0.2),
              child: Row(
                children: [
                  Container(
                    height: 6,
                    width: 60 / 99 * manorTemp,
                    color: temperColors[level ?? 2],
                  )
                ],
              )
            ),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _makeTempLabelAndBar(),
              Container(
                margin: const EdgeInsets.only(left: 7),
                width: 30,
                height: 30,
                child: Image.asset("assets/images/level-${level ?? 2}.jpg"),
              )
            ],
          ),
          Text(
            "매너온도",
            style: TextStyle(
              decoration: TextDecoration.underline,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],)
    );
  }
}