import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

//1. Workspace Crawler (Monorepo Support)
//Why it's used: Modern Dart projects often use Workspaces (monorepos), where one master folder contains multiple smaller sub-packages listed under a workspace: key in pubspec.yaml.

String getPubspecPath(String root) => path.join(root, 'pubspec.yaml');

List<String> getAllWorkspaceNames(String packageRoot) =>
    _getAllWorkspaceNames(packageRoot, <String>[]);

List<String> _getAllWorkspaceNames(String packageRoot, List<String> results) {
  final pubspec = _loadPubspec(packageRoot);
  results.add(pubspec['name'] as String);
  for (final workspace in pubspec['workspace'] as YamlList? ?? []) {
    _getAllWorkspaceNames(path.join(packageRoot, workspace as String), results);
  }
  return results;
}

//It reads the current root's pubspec.yaml using loadYaml and logs its package name.
//If it sees a workspace list property, it loops through those paths, dives into those sub-folders recursively, reads their pubspec.yaml files, and aggregates all sub-package names into a single plain List<String>.
YamlMap _loadPubspec(String packageRoot) {
  final pubspecPath = getPubspecPath(packageRoot);
  final yaml = File(pubspecPath).readAsStringSync();
  return loadYaml(yaml, sourceUrl: Uri.file(pubspecPath)) as YamlMap;
}

//2. extractVMServiceUri (The WebSocket URL Snatcher)
//Why it's used: In coverage.dart, you pass --enable-vm-service=0 to launch the tests. Dart prints a dynamically assigned network URL to the console when it starts up, looking like this:
//The Dart VM service is listening on http://127.0.0.1:58432/ws_auth_token/
// Your coverage collection tool needs that exact address to dial into Dart's memory, but it's buried in a mountain of other terminal logs.

// How it works: This method uses a target Regular Expression (RegExp). It monitors the text output line-by-line, ignores the filler text, captures just the network address string matching the HTTP pattern, parses it into a healthy Uri object, and hands it back to your Completer.
Uri? extractVMServiceUri(String str) {
  final listeningMessageRegExp = RegExp(
    r'(?:Observatory|The Dart VM service is) listening on ((http|//)[a-zA-Z0-9:/=_\-\.\[\]]+)',
  );
  final match = listeningMessageRegExp.firstMatch(str);
  if (match != null) {
    return Uri.parse(match[1]!);
  }
  return null;
}

//3. StandardOutExtension (The Binary Stream Cleaner)
extension StandardOutExtension on Stream<List<int>> {
  Stream<String> lines() =>
      transform(const SystemEncoding().decoder).transform(const LineSplitter());
}
