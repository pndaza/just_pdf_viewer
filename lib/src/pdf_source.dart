import 'dart:async';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Configuration for PDF document opening parameters.
class PdfOpenConfig {
  final PdfPasswordProvider? passwordProvider;
  final bool firstAttemptByEmptyPassword;
  final bool useProgressiveLoading;

  const PdfOpenConfig({
    this.passwordProvider,
    this.firstAttemptByEmptyPassword = true,
    this.useProgressiveLoading = true,
  });

  /// Creates a copy with modified values.
  PdfOpenConfig copyWith({
    PdfPasswordProvider? passwordProvider,
    bool? firstAttemptByEmptyPassword,
    bool? useProgressiveLoading,
  }) {
    return PdfOpenConfig(
      passwordProvider: passwordProvider ?? this.passwordProvider,
      firstAttemptByEmptyPassword: firstAttemptByEmptyPassword ?? this.firstAttemptByEmptyPassword,
      useProgressiveLoading: useProgressiveLoading ?? this.useProgressiveLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PdfOpenConfig &&
        other.passwordProvider == passwordProvider &&
        other.firstAttemptByEmptyPassword == firstAttemptByEmptyPassword &&
        other.useProgressiveLoading == useProgressiveLoading;
  }

  @override
  int get hashCode => Object.hash(
    passwordProvider,
    firstAttemptByEmptyPassword,
    useProgressiveLoading,
  );
}

/// Defines the source of a PDF document.
sealed class PdfSource {
  const PdfSource();

  /// Opens the PDF document with the specified configuration.
  Future<PdfDocument> open([PdfOpenConfig? config]);

  /// Opens the PDF document with individual parameters (deprecated).
  @Deprecated('Use open(PdfOpenConfig) instead')
  Future<PdfDocument> openWithParams({
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = true,
  }) {
    return open(PdfOpenConfig(
      passwordProvider: passwordProvider,
      firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
      useProgressiveLoading: useProgressiveLoading,
    ));
  }
}

/// A PDF source from an asset.
final class AssetSource extends PdfSource {
  final String name;

  const AssetSource(this.name);

  @override
  Future<PdfDocument> open([PdfOpenConfig? config]) {
    final cfg = config ?? const PdfOpenConfig();
    return PdfDocument.openAsset(
      name,
      passwordProvider: cfg.passwordProvider,
      firstAttemptByEmptyPassword: cfg.firstAttemptByEmptyPassword,
      useProgressiveLoading: cfg.useProgressiveLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssetSource && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'AssetSource($name)';
}

/// A PDF source from a file.
final class FileSource extends PdfSource {
  final String filePath;

  const FileSource(this.filePath);

  @override
  Future<PdfDocument> open([PdfOpenConfig? config]) {
    final cfg = config ?? const PdfOpenConfig();
    return PdfDocument.openFile(
      filePath,
      passwordProvider: cfg.passwordProvider,
      firstAttemptByEmptyPassword: cfg.firstAttemptByEmptyPassword,
      useProgressiveLoading: cfg.useProgressiveLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileSource && other.filePath == filePath;
  }

  @override
  int get hashCode => filePath.hashCode;

  @override
  String toString() => 'FileSource($filePath)';
}

/// A PDF source from a byte array.
final class DataSource extends PdfSource {
  final Uint8List data;

  const DataSource(this.data);

  @override
  Future<PdfDocument> open([PdfOpenConfig? config]) {
    final cfg = config ?? const PdfOpenConfig();
    return PdfDocument.openData(
      data,
      passwordProvider: cfg.passwordProvider,
      firstAttemptByEmptyPassword: cfg.firstAttemptByEmptyPassword,
      useProgressiveLoading: cfg.useProgressiveLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataSource && _listEquals(other.data, data);
  }

  @override
  int get hashCode => Object.hashAll(data);

  @override
  String toString() => 'DataSource(${data.length} bytes)';

  /// Helper method to compare Uint8List equality.
  static bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A PDF source from a URI.
final class UriSource extends PdfSource {
  final Uri uri;
  final Map<String, String>? headers;
  final bool withCredentials;

  const UriSource(
    this.uri, {
    this.headers,
    this.withCredentials = false,
  });

  /// Creates a UriSource from a string URL.
  factory UriSource.fromUrl(
    String url, {
    Map<String, String>? headers,
    bool withCredentials = false,
  }) {
    return UriSource(
      Uri.parse(url),
      headers: headers,
      withCredentials: withCredentials,
    );
  }

  @override
  Future<PdfDocument> open([PdfOpenConfig? config]) {
    final cfg = config ?? const PdfOpenConfig();
    return PdfDocument.openUri(
      uri,
      passwordProvider: cfg.passwordProvider,
      firstAttemptByEmptyPassword: cfg.firstAttemptByEmptyPassword,
      headers: headers,
      withCredentials: withCredentials,
      useProgressiveLoading: cfg.useProgressiveLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UriSource &&
        other.uri == uri &&
        _mapEquals(other.headers, headers) &&
        other.withCredentials == withCredentials;
  }

  @override
  int get hashCode => Object.hash(uri, headers, withCredentials);

  @override
  String toString() => 'UriSource($uri)';

  /// Helper method to compare Map equality.
  static bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Extension methods for PdfSource.
extension PdfSourceExtensions on PdfSource {
  /// Opens the PDF document with default configuration.
  Future<PdfDocument> openDefault() => open();

  /// Opens the PDF document with a password provider.
  Future<PdfDocument> openWithPassword(PdfPasswordProvider passwordProvider) {
    return open(PdfOpenConfig(passwordProvider: passwordProvider));
  }

  /// Opens the PDF document without progressive loading.
  Future<PdfDocument> openWithoutProgressiveLoading() {
    return open(const PdfOpenConfig(useProgressiveLoading: false));
  }
}