part of jaguar.http.request;

/// Abstract class for fields on `multipart/form-data`
abstract class FormField<T> {
  /// Name of the field
  String get name;

  /// Value of the field
  T get value;

  /// content-type of the field
  ContentType get contentType;

  bool operator ==(other) {
    if (other is FormField<T>)
      return name == other.name &&
          value == other.value &&
          contentType == other.contentType;
    return false;
  }

  /// Hash code
  int get hashCode => name.hashCode;
}

/// String field in the `multipart/form-data`
///
/// Contains `String` value
class StringFormField implements FormField {
  /// Name of the field
  final String name;

  /// Value of the field
  final String value;

  /// content-type of the field
  final ContentType contentType;

  StringFormField(this.name, this.value, {this.contentType});

  bool operator ==(other) {
    if (other is! StringFormField) {
      return false;
    }

    return _equality(other as StringFormField);
  }

  bool _equality(StringFormField other) {
    return name == other.name &&
        value == other.value &&
        contentType.mimeType == other.contentType.mimeType &&
        contentType.charset == other.contentType.charset;
  }

  int get hashCode => name.hashCode;

  String toString() {
    return "StringFormField('$name', '$value', '$contentType')";
  }
}

/// Text file field in the `multipart/form-data`
class TextFileFormField implements FormField {
  /// Name of the field
  final String name;

  /// Value of the field
  ///
  /// Returns a stream of text
  final Stream<String> value;

  /// content-type of the field
  final ContentType contentType;

  /// File of the file field
  final String filename;

  TextFileFormField(this.name, this.value, {this.contentType, this.filename});

  bool operator ==(other) {
    return name == other.name &&
        contentType.mimeType == other.contentType.mimeType &&
        contentType.charset == other.contentType.charset &&
        filename == other.filename;
  }

  int get hashCode => name.hashCode;

  String toString() {
    return "FileFormField('$name', '$contentType', '$filename')";
  }

  /// Writes the contents of the file to file at [path]
  Future<void> writeTo(String path, {Encoding encoding: utf8}) async {
    IOSink sink = File(path).openWrite(encoding: encoding);
    await for (String item in value) {
      sink.write(item);
    }
    await sink.flush();
    return sink.close();
  }
}

/// Binary file field in the `multipart/form-data`
class BinaryFileFormField implements FormField {
  /// Name of the field
  final String name;

  /// Value of the field
  final Stream<List<int>> value;

  /// content-type of the field
  final ContentType contentType;

  /// File of the file field
  final String filename;

  BinaryFileFormField(this.name, this.value, {this.contentType, this.filename});

  bool operator ==(other) {
    return name == other.name &&
        contentType.mimeType == other.contentType.mimeType &&
        contentType.charset == other.contentType.charset &&
        filename == other.filename;
  }

  int get hashCode => name.hashCode;

  String toString() {
    return "FileFormField('$name', '$contentType', '$filename')";
  }

  /// Writes the contents of the file to file at [path]
  Future<void> writeTo(String path) async {
    IOSink sink = File(path).openWrite();
    await for (List<int> item in value) {
      sink.add(item);
    }
    await sink.flush();
    return sink.close();
  }
}
