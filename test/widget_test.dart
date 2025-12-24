import 'package:flutter_test/flutter_test.dart';

import 'package:ihaveit/main.dart';
import 'package:ihaveit/github_client.dart';

void main() {
  testWidgets('Shows token input when no token is stored', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        client: GitHubClient(),
        tokenStore: InMemoryTokenStore(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Enter GitHub token'), findsOneWidget);
    expect(find.text('Personal Access Token'), findsOneWidget);
    expect(find.byType(TokenInputPage), findsOneWidget);
  });
}
