import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    final jyotish = Jyotish();
    await jyotish.initialize(ephemerisPath: p.absolute('ephe'));
  });

  group('Flutter Widgets & CustomPainters Test Suite', () {
    late VedicChart chart;
    const location = GeographicLocation(
      latitude: 28.6139,
      longitude: 77.2090,
      altitude: 216.0,
      timezone: 'Asia/Kolkata',
    );

    setUp(() async {
      chart = await Jyotish().calculateVedicChart(
        dateTime: DateTime(2000, 1, 1, 12, 0),
        location: location,
      );
    });

    // 1. VedicChartView North Indian rendering
    testWidgets('renders VedicChartView with North Indian style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VedicChartView(
                chart: chart,
                style: ChartStyle.northIndian,
                size: const Size(400, 400),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VedicChartView), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // 2. VedicChartView South Indian rendering
    testWidgets('renders VedicChartView with South Indian style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VedicChartView(
                chart: chart,
                style: ChartStyle.southIndian,
                size: const Size(400, 400),
                darkTheme: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VedicChartView), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // 3. shouldRepaint equality checks
    test('NorthIndianChartPainter shouldRepaint property-based behavior', () {
      final painter1 = NorthIndianChartPainter(chart: chart);
      final painter2 = NorthIndianChartPainter(chart: chart);
      final painterDifferentColor = NorthIndianChartPainter(
        chart: chart,
        strokeColor: Colors.red,
      );

      // Same properties -> should NOT repaint
      expect(painter1.shouldRepaint(painter2), isFalse);

      // Changed color -> SHOULD repaint
      expect(painter1.shouldRepaint(painterDifferentColor), isTrue);
    });

    test('SouthIndianChartPainter shouldRepaint property-based behavior', () {
      final painter1 = SouthIndianChartPainter(chart: chart);
      final painter2 = SouthIndianChartPainter(chart: chart);
      final painterDifferentColor = SouthIndianChartPainter(
        chart: chart,
        textColor: Colors.blue,
      );

      // Same properties -> should NOT repaint
      expect(painter1.shouldRepaint(painter2), isFalse);

      // Changed text color -> SHOULD repaint
      expect(painter1.shouldRepaint(painterDifferentColor), isTrue);
    });

    // 4. VedicDigitalClock rendering and fast-path sunrise test
    testWidgets('renders VedicDigitalClock with mock or real sunrise', (tester) async {
      Future<(DateTime?, DateTime?)> mockSunriseSunset({
        required DateTime date,
        required GeographicLocation location,
      }) async {
        final sr = DateTime(date.year, date.month, date.day, 6, 0);
        final ss = DateTime(date.year, date.month, date.day, 18, 30);
        return (sr, ss);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VedicDigitalClock(
              location: location,
              getSunriseSunset: mockSunriseSunset,
            ),
          ),
        ),
      );

      // Initial pump shows loader or clock
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VedicDigitalClock), findsOneWidget);
    });

    // 5. VedicAnalogClock rendering
    testWidgets('renders VedicAnalogClock', (tester) async {
      Future<(DateTime?, DateTime?)> mockSunriseSunset({
        required DateTime date,
        required GeographicLocation location,
      }) async {
        final sr = DateTime(date.year, date.month, date.day, 6, 0);
        final ss = DateTime(date.year, date.month, date.day, 18, 30);
        return (sr, ss);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VedicAnalogClock(
              location: location,
              getSunriseSunset: mockSunriseSunset,
              size: 300,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VedicAnalogClock), findsOneWidget);
    });

    // 6. VedicTime fromSunrises direct arithmetic test
    test('VedicTime.fromSunrises computes correct ghatis without FFI calls', () {
      final sunriseToday = DateTime.utc(2025, 5, 1, 6, 0);
      final sunriseTomorrow = DateTime.utc(2025, 5, 2, 6, 0);
      // Halfway through the Vedic day (30 Ghatis)
      final midDay = DateTime.utc(2025, 5, 1, 18, 0);

      final vt = VedicTime.fromSunrises(
        time: midDay,
        currentSunrise: sunriseToday,
        nextSunrise: sunriseTomorrow,
      );

      expect(vt.ghati, equals(30));
      expect(vt.vighati, equals(0));
      expect(vt.totalGhatis, closeTo(30.0, 0.01));
    });
  });
}
