import "dart:io";
import "package:mustache4dart/mustache4dart.dart";

/// Defines a mustache template
class Template {
  File file;
  /// Renders a template when given a map of values as an argument
  Function render;

  Template(File file) {
    this.file = file;
    _init();
  }

  _init() {
    render = compile(file.readAsStringSync());
  }
}